pragma solidity ^0.4.24;

import "./InvoiceTokenERC20.sol";

import "../campaign-mutual-contracts/TwoKeyCampaign.sol";
import "../campaign-mutual-contracts/TwoKeyCampaignIncentiveModels.sol";

import "../libraries/IncentiveModels.sol";
import "../TwoKeyConverterStates.sol";

/**
 * @author Nikola Madjarevic
 * Created at 2/19/19
 */
contract TwoKeyDonationCampaign is TwoKeyCampaign, TwoKeyCampaignIncentiveModels {

    event InvoiceTokenCreated(address token, string tokenName, string tokenSymbol);
    address public erc20InvoiceToken; // ERC20 token which will be issued as an invoice

    uint powerLawFactor = 2;

    string campaignName; // Name of the campaign
    uint campaignStartTime; // Time when campaign starts
    uint campaignEndTime; // Time when campaign ends
    uint minDonationAmountWei; // Minimal donation amount
    uint maxDonationAmountWei; // Maximal donation amount
    uint maxReferralRewardPercent; // Percent per conversion which goes to referrers
    uint campaignGoal; // Goal of the campaign, how many funds to raise
    bool shouldConvertToRefer; // If yes, means that referrer must be converter in order to be referrer
    bool isKYCRequired;
    IncentiveModel rewardsModel; //Incentive model for rewards

    mapping(address => uint) amountUserContributed; //If amount user contributed is > 0 means he's a converter
    mapping(address => uint[]) donatorToHisDonationsInEther;

    //Referral accounting stuff
    mapping(address => uint256) internal referrerPlasma2TotalEarnings2key; // Total earnings for referrers
    mapping(address => uint256) internal referrerPlasmaAddressToCounterOfConversions; // [referrer][conversionId]
    mapping(address => mapping(uint256 => uint256)) internal referrerPlasma2EarningsPerConversion;

    DonationEther[] donations;


    modifier isOngoing {
        require(now >= campaignStartTime && now <= campaignEndTime, "Campaign expired or not started yet");
        _;
    }

    modifier onlyInDonationLimit {
        require(msg.value >= minDonationAmountWei && msg.value <= maxDonationAmountWei, "Wrong contribution amount");
        _;
    }

    modifier goalValidator {
        if(campaignGoal != 0) {
            require(this.balance.add(msg.value) <= campaignGoal,"Goal reached");
        }
        _;
    }

    //Struct to represent donation in Ether
    struct DonationEther {
        address donator; //donator -> address who donated
        uint amount; //donation amount ETH
        uint donationTimestamp; //When was donation created
        uint referrerRewardsEthWei;
        uint totalBounty2key;
    }

    constructor(
        address _moderator,
        string _campaignName,
        string tokenName,
        string tokenSymbol,
        uint [] values,
        bool _shouldConvertToReffer,
        bool _isKYCRequired,
        address _twoKeySingletonesRegistry,
        IncentiveModel _rewardsModel
    ) public {
        erc20InvoiceToken = new InvoiceTokenERC20(tokenName,tokenSymbol,address(this));

        //Emit an event with deployed token address, name, and symbol
        emit InvoiceTokenCreated(erc20InvoiceToken, tokenName, tokenSymbol);

        moderator = _moderator;
        campaignName = _campaignName;
        maxReferralRewardPercent = values[0];
        campaignStartTime = values[1];
        campaignEndTime = values[2];
        minDonationAmountWei = values[3];
        maxDonationAmountWei = values[4];
        campaignGoal = values[5];
        conversionQuota = values[6];

        shouldConvertToRefer = _shouldConvertToReffer;
        isKYCRequired = _isKYCRequired;

        twoKeySingletonesRegistry = _twoKeySingletonesRegistry;
        rewardsModel = _rewardsModel;
        contractor = msg.sender;
        twoKeyEventSource = TwoKeyEventSource(ITwoKeySingletoneRegistryFetchAddress(_twoKeySingletonesRegistry).getContractProxyAddress("TwoKeyEventSource"));
        ownerPlasma = twoKeyEventSource.plasmaOf(msg.sender);
        received_from[ownerPlasma] = ownerPlasma;
        balances[ownerPlasma] = totalSupply_;
    }


    /**
     * @notice Function to unpack signature and distribute arcs so we can keep trace on referrals
     * @param signature is the signature containing the whole refchain up to the user
     */
    function distributeArcsBasedOnSignature(bytes signature) internal {
        address[] memory influencers;
        address[] memory keys;
        address old_address;
        (influencers, keys,, old_address) = super.getInfluencersKeysAndWeightsFromSignature(signature);
        uint i;
        address new_address;
        // move ARCs based on signature information
        // TODO: Handle failing of this function if the referral chain is too big
        uint numberOfInfluencers = influencers.length;
        for (i = 0; i < numberOfInfluencers; i++) {
            //Validate that the user is converter in order to join
            if(shouldConvertToRefer == true) {
                address eth_address_influencer = twoKeyEventSource.ethereumOf(influencers[i]);
                require(amountUserContributed[eth_address_influencer] > 0);
            }
            new_address = twoKeyEventSource.plasmaOf(influencers[i]);
            if (received_from[new_address] == 0) {
                transferFrom(old_address, new_address, 1);
            } else {
                require(received_from[new_address] == old_address,'only tree ARCs allowed');
            }
            old_address = new_address;

            if (i < keys.length) {
                setPublicLinkKeyOf(new_address, keys[i]);
            }
        }
    }

    /**
     * @notice Function to get all referrers participated in conversion
     * @param converter is the converter (one who did the action and ended ref chain)
     * @return array of addresses (plasma) of influencers
     */
    function getReferrers(address converter) public view returns (address[]) {
        address influencer = twoKeyEventSource.plasmaOf(converter);
        uint n_influencers = 0;
        while (true) {
            influencer = twoKeyEventSource.plasmaOf(received_from[influencer]);
            if (influencer == twoKeyEventSource.plasmaOf(contractor)) {
                break;
            }
            n_influencers++;
        }
        address[] memory influencers = new address[](n_influencers);
        influencer = twoKeyEventSource.plasmaOf(converter);
        while (n_influencers > 0) {
            influencer = twoKeyEventSource.plasmaOf(received_from[influencer]);
            n_influencers--;
            influencers[n_influencers] = influencer;
        }
        return influencers;
    }

    /**
     * @notice Internal function to update referrer mappings with value
     * @param referrerPlasma is referrer plasma address
     * @param reward is the reward referrer earned
     */
    function updateReferrerMappings(address referrerPlasma, uint reward, uint donationId) internal {
        referrerPlasma2Balances2key[referrerPlasma] = reward;
        referrerPlasma2TotalEarnings2key[referrerPlasma] += reward;
        referrerPlasma2EarningsPerConversion[referrerPlasma][donationId] = reward;
        referrerPlasmaAddressToCounterOfConversions[referrerPlasma] += 1;
    }

    /**
     * @notice Function to distribute referrer rewards depending on selected model
     * @param converter is the address of the converter
     * @param totalBountyForConversion is total bounty for the conversion
     */
    function distributeReferrerRewards(address converter, uint totalBountyForConversion, uint donationId) internal {
        address[] memory referrers = getReferrers(converter);
        uint numberOfReferrers = referrers.length;

        uint totalBountyTokens = buyTokensFromUpgradableExchange(totalBountyForConversion, address(this));

        // Update donation object (directly in the storage)
        DonationEther d = donations[donationId];
        d.totalBounty2key = totalBountyTokens;

        //Distribute rewards based on model selected
        if(rewardsModel == IncentiveModel.AVERAGE) {
            uint reward = IncentiveModels.averageModelRewards(totalBountyForConversion, numberOfReferrers);
            for(uint i=0; i<numberOfReferrers; i++) {
                updateReferrerMappings(referrers[i], reward, donationId);
            }
        } else if(rewardsModel == IncentiveModel.AVERAGE_LAST_3X) {
            uint rewardPerReferrer;
            uint rewardForLast;
            (rewardPerReferrer, rewardForLast)= IncentiveModels.averageLast3xRewards(totalBountyForConversion, numberOfReferrers);
            for(i=0; i<numberOfReferrers - 1; i++) {
                updateReferrerMappings(referrers[i], rewardPerReferrer, donationId);
            }
            updateReferrerMappings(referrers[numberOfReferrers-1], rewardForLast, donationId);
        } else if(rewardsModel == IncentiveModel.POWER_LAW) {
            uint[] memory rewards = IncentiveModels.powerLawRewards(totalBountyForConversion, numberOfReferrers, powerLawFactor);
            for(i=0; i<numberOfReferrers; i++) {
                updateReferrerMappings(referrers[i], rewards[i], donationId);
            }
        }
    }

    /**
     * @notice Function to join with signature and share 1 arc to the receiver
     * @param signature is the signature generatedD
     * @param receiver is the address we're sending ARCs to
     */
    function joinAndShareARC(bytes signature, address receiver) public {
        distributeArcsBasedOnSignature(signature);
        transferFrom(twoKeyEventSource.plasmaOf(msg.sender), twoKeyEventSource.plasmaOf(receiver), 1);
    }

    /**
     * @notice Function where user can join to campaign and donate funds
     * @param signature is signature he's joining with
     */
    //TOOO: Get bakc modifiers isOngoing
    function joinAndDonate(bytes signature) public goalValidator onlyInDonationLimit payable {
        distributeArcsBasedOnSignature(signature);
        uint referrerReward = (msg.value).mul(maxReferralRewardPercent).div(100 * (10**18));
        DonationEther memory donation = DonationEther(msg.sender, msg.value, block.timestamp, referrerReward, 0);
        uint id = donations.length; // get donation id
        donations.push(donation); // add donation to array of donations
        donatorToHisDonationsInEther[msg.sender].push(id); // accounting for the donator
        amountUserContributed[msg.sender] += msg.value; // user contributions

        //Distribute referrer rewards between influencers regarding selected incentive model
        distributeReferrerRewards(msg.sender, referrerReward, id);
        //How many ethers sent, that much invoice tokens you get
        InvoiceTokenERC20(erc20InvoiceToken).transfer(msg.sender, msg.value);
    }

    /**
     * @notice Function where user has already joined and want to donate
     */
    function donate() public goalValidator onlyInDonationLimit isOngoing payable {
        address _converterPlasma = twoKeyEventSource.plasmaOf(msg.sender);
        require(received_from[_converterPlasma] != address(0));
        uint referrerReward = (msg.value).mul(maxReferralRewardPercent).div(100);
        DonationEther memory donation = DonationEther(msg.sender, msg.value, block.timestamp, referrerReward, 0);
        uint id = donations.length; // get donation id
        donations.push(donation); // add donation to array of donations
        donatorToHisDonationsInEther[msg.sender].push(id); // accounting for the donator
        amountUserContributed[msg.sender] += msg.value;

        //Distribute referrer rewards between influencers regarding selected incentive model
        distributeReferrerRewards(msg.sender, referrerReward, id);

        //How many ethers sent, that much invoice tokens you get
        InvoiceTokenERC20(erc20InvoiceToken).transfer(msg.sender, msg.value);
    }

    /**
     * @notice Function where contractor can update power law factor for the rewards
     */
    function updatePowerLawFactor(uint _newPowerLawFactor) public onlyContractor {
        require(_newPowerLawFactor> 0);
        powerLawFactor = _newPowerLawFactor;
    }

    /**
     * @notice Fallback function to handle input payments -> no referrer rewards in this case
     */
    function () goalValidator onlyInDonationLimit isOngoing payable {
        //TODO: What is the requirement just to donate money
    }

    function getAmountUserDonated(address _donator) public view returns (uint) {
        require(
            msg.sender == contractor ||
            msg.sender == _donator ||
            twoKeyEventSource.isAddressMaintainer(msg.sender)
        );
        return amountUserContributed[_donator];
    }


    /**
    * @notice Function to fetch for the referrer his balance, his total earnings, and how many conversions he participated in
    * @dev only referrer by himself, moderator, or contractor can call this
    * @param _referrer is the address of referrer we're checking for
    * @param signature is the signature if calling functions from FE without ETH address
    * @param donationIds are the ids of conversions this referrer participated in
    * @return tuple containing this 3 information
    */
    function getReferrerBalanceAndTotalEarningsAndNumberOfConversions(address _referrer, bytes signature, uint[] donationIds) public view returns (uint,uint,uint,uint[]) {
        if(_referrer != address(0)) {
            require(msg.sender == _referrer || msg.sender == contractor || twoKeyEventSource.isAddressMaintainer(msg.sender));
            _referrer = twoKeyEventSource.plasmaOf(_referrer);
        } else {
            bytes32 hash = keccak256(abi.encodePacked(keccak256(abi.encodePacked("bytes binding referrer to plasma")),
                keccak256(abi.encodePacked("GET_REFERRER_REWARDS"))));
            _referrer = Call.recoverHash(hash, signature, 0);
        }
        uint length = donationIds.length;
        uint[] memory earnings = new uint[](length);
        for(uint i=0; i<length; i++) {
            earnings[i] = referrerPlasma2EarningsPerConversion[_referrer][donationIds[i]];
        }
        return (referrerPlasma2Balances2key[_referrer], referrerPlasma2TotalEarnings2key[_referrer], referrerPlasmaAddressToCounterOfConversions[_referrer], earnings);
    }

    /**
     * @notice Function to read donation
     * @param donationId is the id of donation
     */
    function getDonation(uint donationId) public view returns (bytes) {
        DonationEther memory donation = donations[donationId];
        return abi.encodePacked(
            donation.donator,
            donation.amount,
            donation.donationTimestamp,
            donation.referrerRewardsEthWei,
            donation.totalBounty2key
        );
    }

    /**
     * @notice Contractor can withdraw funds only if criteria is satisfied
     */
    function withdrawContractor() public onlyContractor {
        require(this.balance >= campaignGoal); //Making sure goal is reached
        require(block.timestamp > campaignEndTime); //Making sure time has expired
        super.withdrawContractor();
    }

    function getIncentiveModel() public view returns (IncentiveModel) {
        return rewardsModel;
    }
    /**
     * @notice Function interface for moderator or referrer to withdraw their earnings
     * @param _address is the one who wants to withdraw
     */
    function withdrawModeratorOrReferrer(address _address) public {
        require(this.balance >= campaignGoal); //Making sure goal is reached
        require(block.timestamp > campaignEndTime); //Making sure time has expired
        require(msg.sender == _address);
        super.withdrawModeratorOrReferrer(_address);
    }
}
