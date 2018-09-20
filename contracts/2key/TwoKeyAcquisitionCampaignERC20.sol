pragma solidity ^0.4.24;

import "../openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./TwoKeyTypes.sol";
import "./TwoKeyCampaignARC.sol";
import "./TwoKeyEventSource.sol";
import "./TwoKeyWhitelisted.sol";
import "./TwoKeyEconomy.sol";
import "./TwoKeySignedContract.sol";
import "../interfaces/IERC20.sol";
import "./Utils.sol";

/// @author Nikola Madjarevic
/// Contract which will represent campaign for the fungible assets
contract TwoKeyAcquisitionCampaignERC20 is TwoKeyCampaignARC, TwoKeyTypes, Utils {

    /// Using safemath to avoid overflows during math operations
    using SafeMath for uint256;

    /*  Questions:
            1. Should mapping where we store conversions by address be public? (getter for msg.sender only for now)
            2. Maybe we can even remove assetName and whenever we need it,
                we can call view function for IERC20 and check it's value
            3. ARCS can't be divided, do we need to specify somewhere that decimals for arcs are equal to 0?
            4. uint256 unit_decimals;  // units being sold can be fractional
                (for example tokens in ERC20) (Udi) (Do we need this as global var?)
            5. Does mapping publicLinkKey need to allow only msg.sender to read his key or anyone
                can access it (it can be public that's Q)?
            6. getReferrerCuts private? getReferrerCuts? If you're the contractor or moderator you can get all data, otherwise you can get yours cut
        Contract changes:
            1. Rename in conversion payout --> contractorProceeds
            2. Add 1 more attribute to Conversion object called 'isRejectedByModerator'
            3. Rename isCancelled --> isCancelledByConvertor
            4. openingTime --> campaignStartTime
            5. closingTime --> campaignEndTime
            6. influencer2cut --> referrer2cut (to be more explicit)
            7. referrer2cut mapping is not anymore public (We'll add getter where only
                msg.sender can get his conversion)
            8. assetContract --> assetContractERC20
            9. whitelisted contracts -> referrerWhitelist, converterWhitelist
           10. Removed 'contractorProceeds' variable
           11. escrowPercentage --> moderatorFeePercentage
           12. removed 'name' variable
           13. removed 'ipfsHash' variable
           14. add publicMetaHash, privateMetaHash
           15. Remove 'symbol' variable since it's the same as assetName
           16. Rename assetName --> assetSymbol
           17. Rename quota --> conversionQuota
           18. Rename addFungibleAsset --> addUnitsToInventory
           19. Modified constructor + order in constructor of params + added some new params
           20. Rename public_link_key --> publicLinkKey
           21. Modified publicLinkKey is not 'public' anymore
           22. checkAndUpdateInventoryBalance -> getAndUpdateInventoryBalance
           23. checkInventoryBalance -> getInventoryBalance
           24. Reorganize code that we have it in areas like 'PARAMS - STATE',
            'CONSTRUCTOR','METHODS', 'GETTERS', 'SETTERS', etc.
           25. Add some getters (for cut, publink etc)
           26. joinAndSetPublicLinkWithCut -> add distributeArcsBasedOnSignature
           27. tranferSig --> distributeArcsBasedOnSignature
           28. getCut --> getReferrerCuts
           29. Add getEstimatedTokenAmount function to calculate baseAssetAmount and bonusAssetAmount
           30. Add setAssetContractAttributes method for inheriting decimals and symbol from assetContractERC20
           31. Add getContractAttributes method to get assetSymbol and assetDecimals
    */


    // ==============================================================================================================
    // =====================================TWO KEY ACQUISITION CAMPAIGN EVENTS======================================
    // ==============================================================================================================

    event Fulfilled(address indexed to, uint256 units);
    event Rewarded(address indexed to, uint256 amount);
    event Expired(address indexed _contract);
    event ReceivedEther(address _sender, uint value);

    // ==============================================================================================================
    // =============================TWO KEY ACQUISITION CAMPAIGN STATE VARIABLES=====================================
    // ==============================================================================================================

    /// Structure which will represent conversion
    struct Conversion {
        address contractor; // Contractor (creator) of campaign
        uint256 contractorProceeds; // How much contractor will receive for this conversion
        address converter; // Converter is one who's buying tokens
        bool isFulfilled; // Conversion finished (processed)
        bool isCancelledByConverter; // Canceled by converter
        bool isRejectedByModerator; // Rejected by moderator
        string assetSymbol; // Name of ERC20 token we're selling in our campaign (we can get that from contract address)
        address assetContractERC20; // Address of ERC20 token we're selling in our campaign
        uint256 conversionAmount; // Amount for conversion (In ETH)
        CampaignType campaignType; // Enumerator representing type of campaign (This one is however acquisition)
        uint256 campaignStartTime; // When campaign actually starts
        uint256 campaignEndTime; // When campaign actually ends
    }

    // Mapping conversion to user address
    mapping(address => Conversion) public conversions;

    // Mapping representing how much are cuts in percent(0-100) for referrer address
    mapping(address => uint256) referrer2cut;

    /// Amount converter put to the contract in Ether
    mapping(address => uint) balancesConvertersETH;

    // Number of units (ERC20 tokens) bought
    mapping(address => uint256) public units;

    // the 2key link generated by the owner of this contract contains a secret which is a private key,
    // this is the public part of this secret
    // First address is person who started TwoKeyLink (convertor,contractor, influencer)
    mapping(address => address) publicLinkKey;

    // Balance will represent how many that tokens (erc20) we have on our Campaign
    uint campaignInventoryUnitsBalance;

    // Asset contract is address of ERC20 inventory
    address assetContractERC20;

    // asset symbol is short name of the asset for example "2key"
    string assetSymbol;

    // TwoKeyEconomy contract (ERC20)
    TwoKeyEconomy twoKeyEconomy;

    // Contract representing whitelisted referrer
    TwoKeyWhitelisted referrerWhitelist;

    // Contract representing whitelisted converter
    TwoKeyWhitelisted converterWhitelist;

    IERC20 fungibleInterface;

    // There's single price for the unit ERC20 (Should be in WEI)
    uint256 pricePerUnitInETH;

    // Rate of conversion from TwoKey to ETC
    uint256 public rate = 1;

    // Time when campaign start
    uint256 campaignStartTime;

    // Time when campaign ends
    uint256 campaignEndTime;

    // Address of moderator
    address moderator;

    // How long convertor can be pending before it will be automatically rejected and funds will be returned to convertor
    uint256 expiryConversion;

    // How long will hold asset in escrow
    uint256 moderatorFeePercentage;

    // Ipfs hash of json campaign object
    string public publicMetaHash;

    // Ipfs hash of json sensitive (contractor) information
    string privateMetaHash;

    // maxRefferalRewardPercent is actually bonus percentage in ETH
    uint256 public maxReferralRewardPercent;

    //translates to discount - we can add this to constructor
    uint maxConverterBonusPercent;

    // units being sold can be fractional (for example tokens in ERC20)
    uint unit_decimals;

    // Minimal amount of ETH that can be paid by converter to create conversion
    uint minContributionETH;

    // Maximal amount of ETH that can be paid by converter to create conversion
    uint maxContributionETH;


    /*
     Someone buys with 100 ETH
     Price per unit in ETH is 0.01
     maxConverterBonusPercent is 40%
     In this campaign each converter gets maximum
     maxConverterBonusPercent means that the converter will bi eligible to get 140 ETH worth of tokens which still cost 0.01 ETH
     14000 tokens
     100 / 14000 = .007142857 - actual price per token with the bonus
     (0.01 - .007142857) / 0.01  = .2857143 - this itruffs the actual discount
    */




    // ==============================================================================================================
    // =============================TWO KEY ACQUISITION CAMPAIGN MODIFIERS===========================================
    // ==============================================================================================================


    /// @notice Modifier which is going to check if current time is between opening-closing campaign time
    modifier isOngoing() {
        require(block.timestamp >= campaignStartTime && block.timestamp <= campaignEndTime);
        _;
    }

    /// @notice Modifier which is going to check if campaign is closed (if time is greater then closing time)
    modifier isClosed() {
        require(now > campaignEndTime);
        _;
    }

    /// @notice Modifier to check is the influencer eligible for participation in campaign
    modifier isWhiteListedInfluencer() {
        require(referrerWhitelist.isWhitelisted(msg.sender));
        _;
    }

    /// @notice Modifier to check is the converter eligible for participation in conversion
    modifier isWhitelistedConverter() {
        require(converterWhitelist.isWhitelisted(msg.sender));
        _;
    }


    /// @notice Modifier to check if the Converter did the conversion
    modifier didConverterConvert() {
        Conversion memory c = conversions[msg.sender];
        require(!c.isFulfilled && !c.isCancelledByConverter);
        _;
    }




    // ==============================================================================================================
    // =============================TWO KEY ACQUISITION CAMPAIGN CONSTRUCTOR=========================================
    // ==============================================================================================================

    constructor(address _twoKeyEventSource, address _twoKeyEconomy,
        address _converterWhitelist, address _referrerWhitelist,
        address _moderator, address _assetContractERC20, uint _campaignStartTime, uint _campaignEndTime,
        uint _expiryConversion, uint _moderatorFeePercentage, uint _maxReferralRewardPercent, uint _maxConverterBonusPercent,
        uint _pricePerUnitInETH, uint _minContributionETH, uint _maxContributionETH,
        uint _conversionQuota) TwoKeyCampaignARC(_twoKeyEventSource, _conversionQuota) StandardToken()
    public {
        require(_twoKeyEconomy != address(0));
        require(_converterWhitelist != address(0));
        require(_referrerWhitelist != address(0));
        require(_assetContractERC20 != address(0));
        require(_maxReferralRewardPercent > 0);

        contractor = msg.sender;
        twoKeyEconomy = TwoKeyEconomy(_twoKeyEconomy);
        referrerWhitelist = TwoKeyWhitelisted(_referrerWhitelist);
        converterWhitelist = TwoKeyWhitelisted(_converterWhitelist);
        moderator = _moderator;
        assetContractERC20 = _assetContractERC20;
        campaignStartTime = _campaignStartTime;
        campaignEndTime = _campaignEndTime;
        expiryConversion = _expiryConversion;
        moderatorFeePercentage = _moderatorFeePercentage;
        maxReferralRewardPercent = _maxReferralRewardPercent;
        maxConverterBonusPercent = _maxConverterBonusPercent;

        pricePerUnitInETH = _pricePerUnitInETH;
        minContributionETH = _minContributionETH;
        maxContributionETH = _maxContributionETH;

        setAssetContractAttributes();
        // Emit event that TwoKeyCampaign is created
        twoKeyEventSource.created(address(this), contractor);
        // Set unit_decimals from assetContractERC20
        //            unit_decimals = IERC20(assetContractERC20).decimals();
        // Set Token Symbol from assetContractERC20
        //            assetSymbol = IERC20(assetContractERC20).symbol();
    }

    /// @notice Function which will act as a setter and will be called once during deployment
    function setAssetContractAttributes() private {
        assetSymbol = IERC20(assetContractERC20).symbol();
        unit_decimals = IERC20(assetContractERC20).decimals();
    }

    // TODO: Udis code which sends rewards etc get it
    // TODO: Expiry of conversion event (Two-steps for conversion user puts in ether, and converter being approved by KYC)
    // TODO: When conversion happens, there's timeout where converter can be approved, otherwise everything's transfered to contractor


    /**
     * given the total payout, calculates the moderator fee
     * @param  _conversionAmountETH total payout for escrow
     * @return moderator fee
     */
    function calculateModeratorFee(uint256 _conversionAmountETH) internal view returns (uint256)  {
        if (moderatorFeePercentage > 0) {// send the fee to moderator
            uint256 fee = _conversionAmountETH.mul(moderatorFeePercentage).div(100).div(10 ** unit_decimals);
            return fee;
        }
        return 0;
    }

    /// @notice Method to add fungible asset to our contract
    /// @dev When user calls this method, he just says the actual amount of ERC20 he'd like to transfer to us
    /// @param _amount is the amount of ERC20 contract he'd like to give us
    /// @return true if successful, otherwise transaction will revert
    function addUnitsToInventory(uint256 _amount) public returns (bool) {
        require(
            assetContractERC20.call(
                bytes4(keccak256("transferFrom(address,address,uint256)")),
                msg.sender,
                address(this),
                _amount
            )
        );
        campaignInventoryUnitsBalance += _amount;
        return true;
    }


    function cancelledEscrow(address _converter, address _assetContract, uint256 _amount) internal {
        Conversion memory c = conversions[_converter];
        c.isCancelledByConverter = true;
        conversions[_converter] = c;
        addUnitsToInventory(_amount);
        require(twoKeyEconomy.transfer(_converter, (c.contractorProceeds).mul(rate)));
    }


    function cancelAssetTwoKey(address _converter, string _assetName, address _assetContract, uint256 _amount) public returns (bool) {
        Conversion memory c = conversions[_converter];
        require(!c.isCancelledByConverter && !c.isFulfilled && !c.isRejectedByModerator);
        cancelledEscrow(_converter, _assetContract, _amount);
        twoKeyEventSource.cancelled(address(this), _converter, _assetName, _assetContract, _amount, CampaignType.CPA_FUNGIBLE);

        return true;
    }


    //onlyRole(ROLE_CONTROLLER) - comment
    function expireEscrow(address _converter, address _assetContract, uint256 _amount) public returns (bool) {
        Conversion memory c = conversions[_converter];
        require(!c.isCancelledByConverter && !c.isFulfilled && !c.isRejectedByModerator);
        require(now > c.campaignEndTime);
        cancelledEscrow(_converter, _assetContract, _amount);
        emit Expired(address(this));
        return true;
    }



    /// Is there a need to put assetContract as parameter , address _assetContract also assetName
    /// Also, this function don't need to be payable, we're sending two key tokens here, not eth
    /// (It was payable)
    //    function buyFromWithTwoKey(address _from, string _assetName, uint256 _amount) public {
    //        fulfillFungibleTwoKeyToken(_from, _assetName, _amount);
    //    }

    // @notice Function where an influencer that wishes to cash an _amount of 2key from the campaign can do it
    function redeemTwoKeyToken(uint256 _amount) public {
        require(referrerBalances2KEY[msg.sender] >= _amount && _amount > 0);
        referrerBalances2KEY[msg.sender] = referrerBalances2KEY[msg.sender].sub(_amount);
        twoKeyEconomy.transferFrom(this, msg.sender, _amount);
    }

    //TODO: Remove last two params
    function joinAndSetPublicLinkWithCut(bytes signature, address _public_link_key, uint256 cut) {
        distributeArcsBasedOnSignature(signature);
        setPublicLinkKey(_public_link_key);
        setCut(cut);
    }

    // TODO: we need method joinAndShareARC to different address
    // Scenario where you join by yourself
    function joinAndShareARC(bytes signature, address receiver) public {
        distributeArcsBasedOnSignature(signature);
//        transfer(receiver, 1);
        transferFrom(msg.sender, receiver, 1);
    }

    /// At the beginning only contractor can call this method bcs he is the only one who has arcs
    function setPublicLinkKey(address _public_link_key) public {
        // Here we're requiring that msg.sender has arcs
        require(balanceOf(msg.sender) > 0);

        // Here we're checking that msg.sender have not previously joined
        require(publicLinkKey[msg.sender] == address(0));
        publicLinkKey[msg.sender] = _public_link_key;
    }

    function setCut(uint256 cut) private {
        // the sender sets what is the percentage of the bounty s/he will receive when acting as an influencer
        // the value 255 is used to signal equal partition with other influencers
        // A sender can set the value only once in a contract
        require(cut <= 100 || cut == 255);
        require(referrer2cut[msg.sender] == 0);
        if (cut <= 100) {
            cut++;
        }
        referrer2cut[msg.sender] = cut;
    }
    /// TODO: setPublicLinkKey here
    /// @notice Method distributes arcs based on signature
    /// @param sig is the signature generated on frontend side
    function distributeArcsBasedOnSignature(bytes sig) public {
        // move ARCs based on signature information
        // if version=1, with_cut is true then sig also include the cut (percentage) each influencer takes from the bounty
        // the cut is stored in influencer2cut
        uint idx = 0;
        //    uint8 version;
        //    if (idx+1 <= sig.length) {
        //      idx += 1;
        //      assembly
        //      {
        //        version := mload(add(sig, idx))
        //      }
        //    }
        //    require(version < 2);
        //    bool with_cut = false;
        //    if (version == 1) {
        //      with_cut = true;
        //    }

        address old_address;
        if (idx + 20 <= sig.length) {
            idx += 20;
            assembly
            {
                old_address := mload(add(sig, idx))
            }
        }

        address old_public_link_key = publicLinkKey[old_address];
        require(old_public_link_key != address(0));

        while (idx + 65 <= sig.length) {
            // The signature format is a compact form of:
            //   {bytes32 r}{bytes32 s}{uint8 v}
            // Compact means, uint8 is not padded to 32 bytes.
            idx += 32;
            bytes32 r;
            assembly
            {
                r := mload(add(sig, idx))
            }

            idx += 32;
            bytes32 s;
            assembly
            {
                s := mload(add(sig, idx))
            }

            idx += 1;
            uint8 v;
            assembly
            {
                v := mload(add(sig, idx))
            }

            bytes32 hash;
            address new_public_key;
            address new_address;
            //      if (idx + (with_cut ? 41 : 40) < sig.length) {
            if (idx + 41 < sig.length) {// its  a < and not a <= because we don't want this to be the final iteration for the converter
                uint8 bounty_cut;
                //        if (with_cut)
                {
                    idx += 1;
                    assembly
                    {
                        bounty_cut := mload(add(sig, idx))
                    }
                    require(bounty_cut > 0);
                    // 0 and 255 are used to indicate default (equal part) behaviour
                }

                idx += 20;
                assembly
                {
                    new_address := mload(add(sig, idx))
                }

                idx += 20;
                assembly
                {
                    new_public_key := mload(add(sig, idx))
                }

                //        if (with_cut)
                {
                    //          require(bounty_cut > 0);
                    if (referrer2cut[new_address] == 0) {
                        referrer2cut[new_address] = uint256(bounty_cut);
                    } else {
                        require(referrer2cut[new_address] == uint256(bounty_cut));
                    }
                    hash = keccak256(abi.encodePacked(bounty_cut, new_public_key, new_address));
                }
                //        else {
                //          hash = keccak256(abi.encodePacked(new_public_key, new_address));
                //        }
            } else {
                require(idx == sig.length);
                // signed message for the last step is the address of the converter
                new_address = msg.sender;
                hash = keccak256(abi.encodePacked(new_address));
            }
            // assume users can take ARCs only once... this could be changed
            if (received_from[new_address] == 0) {
                transferFrom(old_address, new_address, 1);
            } else {
                require(received_from[new_address] == old_address);
            }
            // check if we received a valid signature
            address signer = ecrecover(hash, v, r, s);
            if (signer != old_public_link_key) {
                revert();
            }
            old_public_link_key = new_public_key;
            old_address = new_address;
        }
        //    require(idx == sig.length);
    }

    //=====================
    //ENTRY POINT CONVERSION:

    /// With this method we're moving arcs and buying the product (ETH)
    // We receive ether
    // How can I get bonus percentage?
    /*
        (1) We put Ether (converter sends ether)
        (2) We compute tokens
        (2) We create conversion object
        (2) we can't do anything until converter is whitelisted

        (3) Then we need another function that requires converter to be whitelisted and should do the following:
            - Compute referral rewards and distribute then
            - Compute and distribute moderation fees then
            - Generate lock-up contracts for tokens then
            - Move tokens to lock-up contracts then
            - Send remaining ether to contractor
    */

    //******************************************************
    //(1) ENTRY POINTS
    //TODO: andrii if user wants to convert with metamask, they need to choose metamask before you call create their sig and call this function
    //Write call free_take before calling this @Andri
    function joinAndConvert(bytes signature) public payable {
        require(msg.value >= minContributionETH);
        require(msg.value <= maxContributionETH);
        distributeArcsBasedOnSignature(signature);
        createConversion(msg.value, msg.sender);
    }

    function convert() public payable {
        require(msg.value >= minContributionETH);
        require(msg.value <= maxContributionETH);
        require(received_from[msg.sender] != address(0));
        createConversion(msg.value, msg.sender);
    }

    //TODO: for paying with external address, the user needs to transfer an ARC to the external address, and then we can call the public default payable
    function() external payable {
        require(msg.value >= minContributionETH);
        require(balanceOf(msg.sender) > 0);
        createConversion(msg.value, msg.sender);
    }

    //******************************************************
    //(2) CONVERSION 1st STEP

    /// @notice Function to create conversion
    /// @param conversionAmountETH is actually the msg.value (amount of ether)
    /// @param converterAddress is actually the msg.sender (Address of one who's executing conversion)
    /// isOngoing
    function createConversion(uint conversionAmountETH, address converterAddress) private {
        /*
        (2) We get the ETH amount -DONE
        (3) we compute tokens = base + bonus tokens - DONE
        (2) We create conversion object - DONe
        (2) we can't do anything until converter is whitelisted
        */

        uint baseTokensForConverter;
        uint bonusTokensForConverter;

        (baseTokensForConverter, bonusTokensForConverter) = getEstimatedTokenAmount(conversionAmountETH);

        uint totalTokensForConverter = baseTokensForConverter + bonusTokensForConverter;

        // TODO: converter 100ETH, maxRefRewPercent = 10%, ModeratorFee = 1%, =>
        // TODO: maxRefRewETH = 10ETH, moderatorFeeETH = 1ETH
        // TODO: contractorProceedsETH = 100ETH - 10ETH - 1ETH
        // TODO: need additional variable for current2KeyPriceInETH() (now we can use pricePerUnitInETH)
        // TODO: all fees and ref rewards distribute in 2Key

        uint256 maxReferralRewardETH = conversionAmountETH.mul(maxReferralRewardPercent).div(100).div(10 ** unit_decimals);
//        uint256 maxReferralRewardETH = totalTokensForConverter.mul(maxReferralRewardPercent).div(100).div(10 ** unit_decimals);
        //        uint256 moderatorFeeETH = calculateModeratorFee(c.contractorProceeds);
        uint256 moderatorFeeETH = calculateModeratorFee(conversionAmountETH);

        uint256 contractorProceeds = conversionAmountETH - maxReferralRewardETH - moderatorFeeETH;

        Conversion memory c = Conversion(contractor, contractorProceeds, converterAddress, false, false, false, assetSymbol, assetContractERC20, conversionAmountETH, CampaignType.CPA_FUNGIBLE, now, now + expiryConversion * 1 days);

        emit ReceivedEther(converterAddress, conversionAmountETH);
        // move funds
        // campaignInventoryUnitsBalance = campaignInventoryUnitsBalance - totalTokensForConverter;

        // value in escrow (msg.value), total amount of tokens
        // twoKeyEventSource.escrow(address(this), msg.sender, _assetName, _assetContract, _amount, CampaignType.CPA_FUNGIBLE);
        conversions[converterAddress] = c;

    }


    //******************************************************
    //(3) CONVERSION 2nd STEP
    //actually third step after the moderator/contractor approved the converter in the white list

    function executeConversion() isWhitelistedConverter didConverterConvert public {
        // TODO: convert ETH to 2Key for moderator and referrers
        performConversion();
        //require(transferFungibleAsset(msg.sender, _amount));
    }

    function performConversion() internal {
        /*
         (3) Then we need another function that requires converter to be whitelisted and should do the following:
            - Compute referral rewards and distribute then
            - Compute and distribute moderation fees then
            - Generate lock-up contracts for tokens then
            - Move tokens to lock-up contracts then
            - Send remaining ether to contractor

        */

        Conversion memory c = conversions[msg.sender];
        conversions[msg.sender] = c;

        address _converterAddress;
        // Example; MaxReferralReward = 10% then msg.value = 100ETH
        // then this conversionReward = 10ETH
        // TODO: this function has to be part of conversion
        uint _units = 1;
        updateRefchainRewards(_units, maxReferralRewardPercent);

        //TODO distribute refchainRewards

        //TODO distribute moderator fee

        //TODO distribute contractor proceeds

        //TODO either send tokens directly to converter for testing,then later actually create lockup contracts and send tokens to them

        //lockup contracts:
        /*
        1. basetokens get sent to 1 lockup contract
        2. bonus tokens are separated to 6 equal portions and sent to 6 lockup contracts.
        3. a lockupcontract has the converter as beneficiary, and a vesting date in which the converter is allowed to pull the tokens to any other address
        4. only other function of the lockupcontract is that the contractor may up to 1 time only, delay the vesting date of the tokens, by no more then maxVestingDaysDelay (param should be in campaign contract),
        and only if the vesting date has not yet arrived.


        */

        //this is if we want a simple test without lockup contracts
        require(assetContractERC20.call(bytes4(keccak256("transfer(address,uint256)")), _converterAddress, _units));


        //uint256 fee = calculateModeratorFee(c.payout);  //TODO take fee from conversion object since we already computed it.

        //require(twoKeyEconomy.transfer(moderator, fee.mul(rate)));

        //uint256 payout = c.payout;
        //uint256 maxReward = maxReferralRewardPercent.mul(payout).div(100);

        // transfer payout - fee - rewards to seller
        //require(twoKeyEconomy.transfer(contractor, (payout.sub(fee).sub(maxReward)).mul(rate)));

        //        transferRewardsTwoKeyToken(c.from, maxReward.mul(rate));
        //        twoKeyEventSource.fulfilled(address(this), c.converter, c.tokenID, c.assetContract, c.indexOrAmount, c.campaignType);

        c.isFulfilled = true;

    }

    //TODO: refactor to take into account bonus + base tokens added to _units
    function updateRefchainRewards(uint256 _units, uint256 _bounty) public payable {
        // buy coins with cut
        // low level product purchase function
        address customer = msg.sender;
        uint256 customer_balance = balanceOf(customer);
        require(customer_balance > 0);

        uint256 _total_units = getInventoryBalance();

        require(_units > 0);
        require(_total_units >= _units);
        address[] memory influencers = getInfluencers(customer);
        //        uint n_influencers = influencers.length;

        // distribute bounty to influencers
        uint256 total_bounty = 0;
        uint max_referral_reward = _bounty.mul(maxReferralRewardPercent).div(100);
        for (uint i = 0; i < influencers.length; i++) {
            uint256 b;
            if (i == influencers.length - 1) {// if its the last influencer then all the bounty goes to it.
                b = _bounty;
            }
            else {
                uint256 cut = referrer2cut[influencers[i]];
                //        emit Log("CUT", influencer, cut);
                if (cut > 0 && cut <= 101) {
                    b = _bounty.mul(cut.sub(1)).mul(maxReferralRewardPercent).div(10000);
                } else {// cut == 0 or 255 indicates equal particine of the bounty
                    b = _bounty.div(influencers.length - i);
                }
            }
            if (b > max_referral_reward) {
                b = max_referral_reward;
            }

            referrerBalancesETH[influencers[i]] = referrerBalancesETH[influencers[i]].add(b);
            emit Rewarded(influencers[i], b);
            total_bounty = total_bounty.add(b);
            _bounty = _bounty.sub(b);
        }

        units[customer] = units[customer].add(_units);

        emit Fulfilled(customer, units[customer]);
    }






    /// Is there a need to put assetContract as parameter , address _assetContract also assetName
    /// Also, this function don't need to be payable, we're sending two key tokens here, not eth
    /// (It was payable)
    //    function buyFromWithTwoKey(address _from, string _assetName, uint256 _amount) public {
    //        fulfillFungibleTwoKeyToken(_from, _assetName, _amount);
    //    }




    /// @notice Move some amount of ERC20 from our campaignInventoryUnitsBalance to someone
    /// @dev internal function
    /// @param _to address we're sending the amount of ERC20
    /// @param _amount is the amount of ERC20's we're going to transfer
    /// @return true if successful, otherwise reverts
    function moveFungibleAsset(address _to, uint256 _amount) internal returns (bool) {
        require(campaignInventoryUnitsBalance >= _amount);
        require(
            assetContractERC20.call(
                bytes4(keccak256(abi.encodePacked("transfer(address,uint256)"))),
                _to, _amount
            )
        );
        campaignInventoryUnitsBalance = campaignInventoryUnitsBalance - _amount;
        return true;
    }

    // transfer an amount of erc20 from our catalogue to someone
    // This should be called when conversion is executed

    /// @notice Function which will transfer fungible assets from contract to someone
    /// @param _to is the address we're sending the fungible assets
    /// @param _amount is the amount of ERC20 we're going to transfer
    /// @return true if trasaction completes otherwise transaction will revert
    function transferFungibleAsset(address _to, uint256 _amount) internal returns (bool) {
        return moveFungibleAsset(_to, _amount);
    }




    // ==============================================================================================================
    // =============================TWO KEY ACQUISITION CAMPAIGN GETTERS=============================================
    // ==============================================================================================================


    /// @notice Function to check how much eth has been sent to contract from address
    /// @param _from is the address we'd like to check balance
    /// @return amount of ether sent to contract from the specified address
    function getAmountAddressSent(address _from) public view returns (uint) {
        return balancesConvertersETH[_from];
    }

    /// @notice Function to check contract balance of specified ERC20 tokens
    /// @return balance
    function getContractBalance() public view returns (uint) {
        return campaignInventoryUnitsBalance;
    }

    /// @notice View function to fetch the address of asset contract
    /// @return address of that asset contract
    function getAssetContractAddress() public view returns (address) {
        return assetContractERC20;
    }

    /// @notice Function to return constantss
    function getConstantInfo() public view returns (uint256, uint256, uint256, uint256) {
        return (pricePerUnitInETH, maxReferralRewardPercent, conversionQuota, unit_decimals);
    }

    /// @notice Function where we can get publicLinkKey for msg.sender [GETTER]
    /// @return public link key
    function getPublicLinkKey() public view returns (address) {
        require(publicLinkKey[msg.sender] != address(0));
        // This means public link key is not set
        return publicLinkKey[msg.sender];
    }

    /// @notice Function which acts like getter for all cuts in array
    /// @param last_influencer is the last influencer
    /// @return array of integers containing cuts respectively
    function getReferrerCuts(address last_influencer) public view returns (uint256[]) {
        address[] memory influencers = getInfluencers(last_influencer);
        uint256[] memory cuts = new uint256[](influencers.length + 1);
        for (uint i = 0; i < influencers.length; i++) {
            address influencer = influencers[i];
            cuts[i] = referrer2cut[influencer];
        }
        cuts[influencers.length] = referrer2cut[last_influencer];
        return cuts;
    }

    /// @notice Function which returns value of maxReferralRewardPercent
    /// @return value of maxReferralRewardPercent as uint256
    function getMaxReferralRewardPercent() public view returns (uint256) {
        return maxReferralRewardPercent;
    }

    /// @notice This is acting as a getter for referrer2cut
    /// @dev Transaction will revert if msg.sender is not present in mapping
    /// @return cut value / otherwise reverts
    function getReferrerCut() public view returns (uint256) {
        require(referrer2cut[msg.sender] != 0);
        return referrer2cut[msg.sender] - 1;
    }


    /// @notice Function to check balance of the ERC20 inventory (view - no gas needed to call this function)
    /// @dev we're using Utils contract and fetching the balance of this contract address
    /// @return balance value as uint
    function getInventoryBalance() public view returns (uint) {
        uint balance = Utils.call_return(assetContractERC20, "balanceOf(address)", uint(this));
        return balance;
    }

    /// @notice Function which will check the balance and automatically update the balance in our contract regarding balance response
    /// @return balance of ERC20 we have in our contract
    function getAndUpdateInventoryBalance() public returns (uint) {
        uint balance = getInventoryBalance();
        campaignInventoryUnitsBalance = balance;
        return balance;
    }


    /// @notice Function which will calculate the base amount, bonus amount
    /// @param conversionAmountETH is amount of eth in conversion
    /// @return tuple containing (base,bonus)
    function getEstimatedTokenAmount(uint conversionAmountETH) public view returns (uint, uint) {
        uint baseTokensForConverter = conversionAmountETH.mul(10 ** unit_decimals).div(pricePerUnitInETH);
        uint bonusTokensForConverter = baseTokensForConverter.mul(maxConverterBonusPercent).div(100).div(10 ** unit_decimals);
        return (baseTokensForConverter, bonusTokensForConverter);
    }

    function getContractAttributes() public view returns (string, uint) {
        return (assetSymbol, unit_decimals);
    }
}
