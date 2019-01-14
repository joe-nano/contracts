pragma solidity ^0.4.24;

import "../openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./TwoKeyCampaignARC.sol";
import "./TwoKeyEventSource.sol";
import "../interfaces/IERC20.sol";
import "./Call.sol";
import "../interfaces/IUpgradableExchange.sol";
import "../interfaces/ITwoKeyConversionHandler.sol";
import "../interfaces/ITwoKeyExchangeRateContract.sol";

/**
 * @author Nikola Madjarevic
 * @notice Campaign which will sell ERC20 tokens
 */
contract TwoKeyAcquisitionCampaignERC20 is TwoKeyCampaignARC {

    using Call for *;
    address public conversionHandler;
    address public upgradableExchange;

    address owner_plasma;

    mapping(address => uint256) referrer2cut; // Mapping representing how much are cuts in percent(0-100) for referrer address
    mapping(address => uint256) internal referrerBalancesETHWei; // balance of EthWei for each influencer that he can withdraw
    mapping(address => uint256) internal referrerTotalEarningsEthWEI; // Total earnings for referrers
    mapping(address => uint256) internal referrerAddressToCounterOfConversions;


    uint moderatorBalanceETHWei; //Balance of the moderator which can be withdrawn
    uint moderatorTotalEarningsETHWei; //Total earnings of the moderator all time

    mapping(address => uint256) balancesConvertersETH; // Amount converter put to the contract in Ether
    mapping(address => uint256) internal units; // Number of units (ERC20 tokens) bought

    string public currency; // currency can be either ETH or USD
    address ethUSDExchangeContract;
    address assetContractERC20; // Asset contract is address of ERC20 inventory
    uint256 contractorBalance;
    uint256 contractorTotalProceeds;
    uint256 pricePerUnitInETHWeiOrUSD; // There's single price for the unit ERC20 (Should be in WEI)
    uint256 campaignStartTime; // Time when campaign start
    uint256 campaignEndTime; // Time when campaign ends
    uint256 expiryConversionInHours; // How long converter can be pending before it will be automatically rejected and funds will be returned to convertor (hours)
    uint256 moderatorFeePercentage; // Fee which moderator gets
    string public publicMetaHash; // Ipfs hash of json campaign object
    string privateMetaHash; // Ipfs hash of json sensitive (contractor) information
    uint256 maxReferralRewardPercent; // maxReferralRewardPercent is actually bonus percentage in ETH
    uint maxConverterBonusPercent; //translates to discount - we can add this to constructor
    uint minContributionETHorFiatCurrency; // Minimal amount of ETH or USD that can be paid by converter to create conversion
    uint maxContributionETHorFiatCurrency; // Maximal amount of ETH or USD that can be paid by converter to create conversion
    uint unit_decimals; // ERC20 selling data
    uint reservedAmountOfTokens = 0;

//    bool public withdrawApproved = false; // Until contractor set this to be true, no one can withdraw funds etc.
//    bool canceled = false; // This means if contractor cancel everything


    /**
     * @notice Modifier which will enable function to be executed in specific time period
     */
    modifier isOngoing() {
        require(block.timestamp >= campaignStartTime && block.timestamp <= campaignEndTime);
        _;
    }

    /**
     * @notice Modifier which will enable only twoKeyConversionHandlerContract to execute some functions
     */
    modifier onlyTwoKeyConversionHandler() {
        require(msg.sender == address(conversionHandler));
        _;
    }

    //TODO: Move expiry conversion in hours to two key conversion handler, no need to store in this contract since it's used there only
    constructor(
        address _twoKeyEventSource,
        address _conversionHandler,
        address _moderator,
        address _assetContractERC20,
        uint [] values,
        string _currency,
        address _ethUSDExchangeContract,
        address _twoKeyUpgradableExchangeContract
    ) TwoKeyCampaignARC (
        _twoKeyEventSource,
        values[9]
    )
    public {
        conversionHandler = _conversionHandler;
        upgradableExchange = _twoKeyUpgradableExchangeContract;
        contractor = msg.sender;
        moderator = _moderator;
        assetContractERC20 = _assetContractERC20;
        campaignStartTime = values[0];
        campaignEndTime = values[1];
        expiryConversionInHours = values[2];
        moderatorFeePercentage = values[3];
        maxReferralRewardPercent = values[4];
        maxConverterBonusPercent = values[5];
        pricePerUnitInETHWeiOrUSD = values[6];
        minContributionETHorFiatCurrency = values[7];
        maxContributionETHorFiatCurrency = values[8];
        currency = _currency;
        ethUSDExchangeContract = _ethUSDExchangeContract;
        unit_decimals = IERC20(assetContractERC20).decimals();
        ITwoKeyConversionHandler(conversionHandler).setTwoKeyAcquisitionCampaignERC20(address(this), _moderator, contractor, _assetContractERC20);
        owner_plasma = _twoKeyEventSource.plasmaOf(msg.sender);
        twoKeyEventSource.created(address(this), contractor, moderator);
    }


    /**
     * given the total payout, calculates the moderator fee
     * @param  _conversionAmountETHWei total payout for escrow
     * @return moderator fee
     */
    function calculateModeratorFee(uint256 _conversionAmountETHWei) internal view returns (uint256)  {
        if (moderatorFeePercentage > 0) {// send the fee to moderator
            uint256 fee = _conversionAmountETHWei.mul(moderatorFeePercentage).div(100);
            return fee;
        }
        return 0;
    }

    /**
     * @notice Method to add fungible asset to our contract
     * @dev When user calls this method, he just says the actual amount of ERC20 he'd like to transfer to us
     * @param _amount is the amount of ERC20 contract he'd like to give us
     * @return true if successful, otherwise transaction will revert
     */
    function addUnitsToInventory(uint256 _amount) public returns (bool) {
        require(IERC20(assetContractERC20).transferFrom(msg.sender, address(this), _amount),'Failed adding units to inventory');
        return true;
    }



    function setCutOf(address me, uint256 cut) internal {
        // what is the percentage of the bounty s/he will receive when acting as an influencer
        // the value 255 is used to signal equal partition with other influencers
        // A sender can set the value only once in a contract
        address plasma = twoKeyEventSource.plasmaOf(me);
        require(referrer2cut[plasma] == 0 || referrer2cut[plasma] == cut, 'cut already set differently');
        referrer2cut[plasma] = cut;
    }

    function setCut(uint256 cut) public {
        setCutOf(msg.sender, cut);
    }

    function getReferrerCut(address me) public view returns (uint256) {
        return referrer2cut[twoKeyEventSource.plasmaOf(me)];
    }

    /**
     * @notice internal function to validate the request is proper
     * @param msgValue is the value of the message sent
     * @dev validates if msg.Value is in interval of [minContribution, maxContribution]
     */
    function requirementForMsgValue(uint msgValue) internal {
        if(keccak256(currency) == keccak256('ETH')) {
            require(msgValue >= minContributionETHorFiatCurrency);
            require(msgValue <= maxContributionETHorFiatCurrency);
        } else {
            uint val;
            bool flag;
            (val, flag,,) = ITwoKeyExchangeRateContract(ethUSDExchangeContract).getFiatCurrencyDetails(currency);
            if(flag) {
                require((msgValue * val).div(10**18) >= minContributionETHorFiatCurrency); //converting ether to fiat
                require((msgValue * val).div(10**18) <= maxContributionETHorFiatCurrency); //converting ether to fiat
            } else {
                require(msgValue >= (val * minContributionETHorFiatCurrency).div(10**18)); //converting fiat to ether
                require(msgValue <= (val * maxContributionETHorFiatCurrency).div(10**18)); //converting fiat to ether
            }
        }
    }

    /**
     * @notice Function where converter can join and convert
     * @dev payable function
     */
    function joinFromAndConvert(address _from, bool _isAnonymous) public payable {
        requirementForMsgValue(msg.value);
        _from = twoKeyEventSource.plasmaOf(_from);
        address _converterPlasma = twoKeyEventSource.plasmaOf(msg.sender);
        if (balanceOf(_converterPlasma) == 0) {
            transferFromInternal(_from, _converterPlasma, 1);
        }
        createConversion(msg.value, _converterPlasma);
        ITwoKeyConversionHandler(conversionHandler).setAnonymous(_converterPlasma, _isAnonymous);
        balancesConvertersETH[_converterPlasma] += msg.value;
        twoKeyEventSource.converted(address(this),_converterPlasma,msg.value);
    }

    /**
     * @notice Function where converter can convert
     * @dev payable function
     */
    function convert(bool _isAnonymous) public payable {
        requirementForMsgValue(msg.value);
        address _converterPlasma = twoKeyEventSource.plasmaOf(msg.sender);
        require(received_from[_converterPlasma] != address(0));
        createConversion(msg.value, _converterPlasma);
        ITwoKeyConversionHandler(conversionHandler).setAnonymous(_converterPlasma, _isAnonymous);
        balancesConvertersETH[_converterPlasma] += msg.value;
        twoKeyEventSource.converted(address(this),_converterPlasma,msg.value);
    }

    /*
     * @notice Function which is executed to create conversion
     * @param conversionAmountETHWei is the amount of the ether sent to the contract
     * @param converterAddress is the sender of eth to the contract
     * @dev can be called only internally
     */
    function createConversion(uint conversionAmountETHWei, address converterPlasmaAddress) internal {
        uint baseTokensForConverterUnits;
        uint bonusTokensForConverterUnits;

        (baseTokensForConverterUnits, bonusTokensForConverterUnits) = getEstimatedTokenAmount(conversionAmountETHWei);

        uint totalTokensForConverterUnits = baseTokensForConverterUnits + bonusTokensForConverterUnits;

        uint256 _total_units = getInventoryBalance();
        require(_total_units - reservedAmountOfTokens >= totalTokensForConverterUnits, 'Inventory balance does not have enough funds');

        units[converterPlasmaAddress] = units[converterPlasmaAddress].add(totalTokensForConverterUnits);

        uint256 maxReferralRewardETHWei = conversionAmountETHWei.mul(maxReferralRewardPercent).div(100);
        uint256 moderatorFeeETHWei = calculateModeratorFee(conversionAmountETHWei);

        uint256 contractorProceedsETHWei = conversionAmountETHWei - maxReferralRewardETHWei - moderatorFeeETHWei;

        reservedAmountOfTokens = reservedAmountOfTokens + totalTokensForConverterUnits;

        ITwoKeyConversionHandler(conversionHandler).supportForCreateConversion(contractor, contractorProceedsETHWei, converterPlasmaAddress,
            conversionAmountETHWei, maxReferralRewardETHWei, moderatorFeeETHWei,
            baseTokensForConverterUnits,bonusTokensForConverterUnits,
            expiryConversionInHours);
    }

    /**
     * @notice Update refferal chain with rewards (update state variables)
     * @param _maxReferralRewardETHWei is the max referral reward set
     * @param _converter is the address of the converter
     * @dev This function can only be called by TwoKeyConversionHandler contract
     */
    function updateRefchainRewards(uint256 _maxReferralRewardETHWei, address _converter) public onlyTwoKeyConversionHandler {
        require(_maxReferralRewardETHWei > 0, 'Max referral reward in ETH must be > 0');
        address converter = _converter;
        address[] memory influencers = getReferrers(converter);

        uint256 total_bounty = 0;
        for (uint i = 0; i < influencers.length; i++) {
            uint256 b;
            if (i == influencers.length - 1) {  // if its the last influencer then all the bounty goes to it.
                b = _maxReferralRewardETHWei;
            }
            else {
                uint256 cut = referrer2cut[influencers[i]];
                if (cut > 0 && cut <= 101) {
                    b = _maxReferralRewardETHWei.mul(cut.sub(1)).div(100);
                } else {// cut == 0 or 255 indicates equal particine of the bounty
                    b = _maxReferralRewardETHWei.div(influencers.length - i);
                }
            }
            //All mappings are now stated to plasma addresses
            referrerBalancesETHWei[influencers[i]] = referrerBalancesETHWei[influencers[i]].add(b);
            referrerTotalEarningsEthWEI[influencers[i]] = referrerTotalEarningsEthWEI[influencers[i]].add(b);
            referrerAddressToCounterOfConversions[influencers[i]]++;
//            emit Rewarded(influencers[i], b);
            total_bounty = total_bounty.add(b);
            _maxReferralRewardETHWei = _maxReferralRewardETHWei.sub(b);
        }
    }


    /**
     * @notice Move some amount of ERC20 from our campaign to someone
     * @dev internal function
     * @param _to address we're sending the amount of ERC20
     * @param _amount is the amount of ERC20's we're going to transfer
     * @return true if successful, otherwise reverts
     */
    function moveFungibleAsset(address _to, uint256 _amount) public onlyTwoKeyConversionHandler returns (bool) {
        require(getInventoryBalance() >= _amount, 'Campaign inventory should be greater than amount');
        require(IERC20(assetContractERC20).transfer(_to,_amount),'Transfer of ERC20 failed');
        return true;
    }


    /**
     * @notice Function to check how much eth has been sent to contract from address
     * @param _from is the address we'd like to check balance
     * @return amount of ether sent to contract from the specified address
     */
    function getAmountAddressSent(address _from) public view returns (uint) {
        return balancesConvertersETH[_from];
    }

    /**
     * @notice Function to return constants
     * @return price, maxReferralRewardPercent, quota for conversion and unit_decimals for erc20
     */
    function getConstantInfo() public view returns (uint256, uint256, uint256, uint256) {
        return (pricePerUnitInETHWeiOrUSD, maxReferralRewardPercent, conversionQuota, unit_decimals);
    }

    /**
     * @notice Function which acts like getter for all cuts in array
     * @param last_influencer is the last influencer
     * @return array of integers containing cuts respectively
     */
    function getReferrerCuts(address last_influencer) public view returns (uint256[]) {
        address[] memory influencers = getReferrers(last_influencer);
        uint256[] memory cuts = new uint256[](influencers.length + 1);
        for (uint i = 0; i < influencers.length; i++) {
            address influencer = influencers[i];
            cuts[i] = getReferrerCut(influencer);
        }
        cuts[influencers.length] = getReferrerCut(last_influencer);
        return cuts;
    }


    /**
     * @notice Function to check balance of the ERC20 inventory (view - no gas needed to call this function)
     * @dev we're using Utils contract and fetching the balance of this contract address
     * @return balance value as uint
     */
    function getInventoryBalance() public view returns (uint) {
        uint balance = IERC20(assetContractERC20).balanceOf(address(this));
        return balance;
    }


    /**
     * @notice Function which will calculate the base amount, bonus amount
     * @param conversionAmountETHWei is amount of eth in conversion
     * @return tuple containing (base,bonus)
     */
    function getEstimatedTokenAmount(uint conversionAmountETHWei) public view returns (uint, uint) {
        uint value = pricePerUnitInETHWeiOrUSD;
        if(keccak256(currency) != keccak256('ETH')) {
            uint rate;
            bool flag;
            (rate,flag,,) = ITwoKeyExchangeRateContract(ethUSDExchangeContract).getFiatCurrencyDetails(currency);
            if(flag) {
                conversionAmountETHWei = (conversionAmountETHWei * rate).div(10 ** 18); //converting eth to $wei
            } else {
                value = (value * rate).div(10 ** 18); //converting dollar wei to eth
            }
        }
        uint baseTokensForConverterUnits = conversionAmountETHWei.mul(10 ** unit_decimals).div(value);
        uint bonusTokensForConverterUnits = baseTokensForConverterUnits.mul(maxConverterBonusPercent).div(100);
        return (baseTokensForConverterUnits, bonusTokensForConverterUnits);
    }


    /**
     * @notice Setter for privateMetaHash
     * @dev only Contractor can call this method, otherwise function will revert
     * @param _privateMetaHash is string representation of private metadata hash
     */
    function setPrivateMetaHash(string _privateMetaHash) public onlyContractorOrModerator {
        privateMetaHash = _privateMetaHash;
    }

    /**
     * @notice Getter for privateMetaHash
     * @dev only Contractor can call this method, otherwise function will revert
     * @return string representation of private metadata hash
     */
    function getPrivateMetaHash() public view onlyContractorOrModerator returns (string) {
        return privateMetaHash;
    }

    /**
     * @notice Function to fetch moderator balance in ETH and his total earnings
     * @dev only contractor or moderator are eligible to call this function
     * @return value of his balance in ETH
     */
    function getModeratorBalanceAndTotalEarnings() external onlyContractorOrModerator view returns (uint,uint) {
        return (moderatorBalanceETHWei,moderatorTotalEarningsETHWei);
    }


    /**
     * @notice Function to update moderator balance and total earnings by conversion handler at the moment of conversion execution
     * @param _value is the value added
     */
    function updateModeratorBalanceETHWei(uint _value) public onlyTwoKeyConversionHandler {
        moderatorBalanceETHWei = moderatorBalanceETHWei.add(_value);
        moderatorTotalEarningsETHWei = moderatorTotalEarningsETHWei.add(_value);
    }


    /**
     * @notice Function to update MinContributionETH
     * @dev only Contractor can call this method, otherwise it will revert - emits Event when updated
     * @param value is the new value we are going to set for minContributionETH
     */
    function updateMinContributionETHOrUSD(uint value) public onlyContractor {
        minContributionETHorFiatCurrency = value;
        twoKeyEventSource.updatedData(block.timestamp, value, "Updated maxContribution");
    }

    /**
     * @notice Function to update maxContributionETH
     * @dev only Contractor can call this method, otherwise it will revert - emits Event when updated
     * @param value is the new maxContribution value
     */
    function updateMaxContributionETHorUSD(uint value) external onlyContractor {
        maxContributionETHorFiatCurrency = value;
        twoKeyEventSource.updatedData(block.timestamp, value, "Updated maxContribution");
    }

    /**
     * @notice Function to update maxReferralRewardPercent
     * @dev only Contractor can call this method, otherwise it will revert - emits Event when updated
     * @param value is the new referral percent value
     */
    function updateMaxReferralRewardPercent(uint value) external onlyContractor {
        maxReferralRewardPercent = value;
        twoKeyEventSource.updatedData(block.timestamp, value, "Updated maxReferralRewardPercent");
    }

    /**
     * @notice Function to update /set publicMetaHash
     * @dev only Contractor can call this function, otherwise it will revert - emits Event when set/updated
     * @param value is the value for the publicMetaHash
     */
    function updateOrSetIpfsHashPublicMeta(string value) public onlyContractor {
        publicMetaHash = value;
        twoKeyEventSource.updatedPublicMetaHash(block.timestamp, value);
    }


    /**
     * @notice Option to update contractor proceeds
     * @dev can be called only from TwoKeyConversionHandler contract
     * @param value it the value we'd like to add to total contractor proceeds and contractor balance
     */
    function updateContractorProceeds(uint value) public onlyTwoKeyConversionHandler {
        contractorTotalProceeds = contractorTotalProceeds.add(value);
        contractorBalance = contractorBalance.add(value);
    }

    /**
     * @notice Function to update amount of the reserved tokens in case conversion is rejected
     * @param value is the amount to reduce from reserved state
     */
    function updateReservedAmountOfTokensIfConversionRejectedOrExecuted(uint value) public onlyTwoKeyConversionHandler {
        require(reservedAmountOfTokens - value >= 0);
        reservedAmountOfTokens = reservedAmountOfTokens - value;
    }

    /**
     * @notice Function to check if the msg.sender has already joined
     * @return true/false depending of joined status
     */
    function getAddressJoinedStatus() public view returns (bool) {
        address plasma = twoKeyEventSource.plasmaOf(msg.sender);
        if(plasma == address(contractor) || msg.sender == address(moderator) || received_from[plasma] != address(0)
            || balanceOf(plasma) > 0) {
            return true;
        }
        return false;
    }

    /**
     * @notice Function to check available amount of the tokens on the contract
     */
    function getAvailableAndNonReservedTokensAmount() external view returns (uint) {
        uint inventoryBalance = getInventoryBalance();
        return (inventoryBalance - reservedAmountOfTokens);
    }

    function sendBackEthWhenConversionCancelled(address _cancelledConverter, uint _conversionAmount) public onlyTwoKeyConversionHandler {
        _cancelledConverter.transfer(_conversionAmount);
    }


    /**
     * @notice Function to fetch contractor balance in ETH
     * @dev only contractor can call this function, otherwise it will revert
     * @return value of contractor balance in ETH WEI
     */
    function getContractorBalance() external onlyContractor view returns (uint) {
        return contractorBalance;
    }

    /**
     * @notice Function to fetch for the referrer his balance, his total earnings, and how many conversions he participated in
     * @dev only referrer by himself, moderator, or contractor can call this
     * @param _referrer is the address of referrer we're checking for
     * @return tuple containing this 3 information
     */
    function getReferrerBalanceAndTotalEarningsAndNumberOfConversions(address _referrer) public view returns (uint,uint,uint) {
        require(msg.sender == _referrer || msg.sender == contractor || msg.sender == moderator);
        _referrer = twoKeyEventSource.plasmaOf(_referrer);
        return (referrerBalancesETHWei[_referrer],referrerTotalEarningsEthWEI[_referrer], referrerAddressToCounterOfConversions[_referrer]);
    }


    /**
     * @notice Function where contractor can withdraw his funds
     * @dev onlyContractor can call this method
     * @return true if successful otherwise will 'revert'
     */
    function withdrawContractor() external onlyContractor {
        uint balance = contractorBalance;
        contractorBalance = 0;
        /**
         * In general transfer by itself prevents against reentrancy attack since it will throw if more than 2300 gas
         * but however it's not bad to practice this pattern of firstly reducing balance and then doing transfer
         */
        contractor.transfer(balance);
    }


    function buyTokensFromUpgradableExchange(uint amountOfMoney, address receiver) private {
        IUpgradableExchange(upgradableExchange).buyTokens.value(amountOfMoney)(receiver);
    }

    /**
     * @notice Function where moderator or referrer can withdraw their available funds
     */
    function withdrawModeratorOrReferrer() external {
        //Creating additional variable to prevent reentrancy attack
        uint balance;
        if(msg.sender == moderator) {
            balance = moderatorBalanceETHWei;
            moderatorBalanceETHWei = 0;
            buyTokensFromUpgradableExchange(balance,msg.sender);
        } else {
            address _referrer = twoKeyEventSource.plasmaOf(msg.sender);
            if(referrerBalancesETHWei[_referrer] != 0) {
                balance = referrerBalancesETHWei[_referrer];
                referrerBalancesETHWei[_referrer] = 0;
                buyTokensFromUpgradableExchange(balance, msg.sender);
            } else {
                revert();
            }
        }
    }

//    /**
//     * @notice This function will be triggered in case converter is rejected
//     */
//    function refundConverterAndRemoveUnits(address _converter, uint amountOfEther, uint amountOfUnits) external onlyTwoKeyConversionHandler {
//        units[_converter] = units[_converter] - amountOfUnits;
//        _converter.transfer(amountOfEther);
//    }


}
