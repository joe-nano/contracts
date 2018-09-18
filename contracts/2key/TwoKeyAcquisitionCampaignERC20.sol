pragma solidity ^0.4.24;

import '../openzeppelin-solidity/contracts/math/SafeMath.sol';
import "./TwoKeyTypes.sol";
import "./TwoKeyCampaignARC.sol";
import "./TwoKeyEventSource.sol";
import "./TwoKeyWhitelisted.sol";
import './TwoKeyEconomy.sol';
import "./TwoKeySignedContract.sol";
import "./Utils.sol";

/// @author Nikola Madjarevic
/// Contract which will represent campaign for the fungible assets
contract TwoKeyAcquisitionCampaignERC20 is TwoKeyCampaignARC, TwoKeyTypes, Utils {


    event Fulfilled(address indexed to, uint256 units);
    event Rewarded(address indexed to, uint256 amount);
    event Expired(address indexed _contract);
    event ReceivedEther(address _sender, uint value);


    /// Using safemath to avoid overflows during math operations
    using SafeMath for uint256;

    /// Structure which will represent conversion
    struct Conversion {
        address from;
        uint256 payout;
        address converter;
        bool isFulfilled;
        bool isCancelled;
        string assetName;
        address assetContract;
        uint256 amount;
        CampaignType campaignType;
        uint256 openingTime;
        uint256 closingTime;
    }



    mapping (address => Conversion) public conversions;
    mapping(address => uint256) public influencer2cut;

    /// Amount converter put to the contract in Ether
    mapping (address => uint) balancesConvertersETH;
    mapping(address => uint256) public units; // number of units bought

    /// Balance will represent how many that tokens (erc20) we have on our Campaign
    uint campaignInventoryUnitsBalance;

    /// asset contract is address of that ERC20 inventory
    address assetContract;

    /// asset name is short name of the asset for example "2key"
    string assetName;

    uint contractorProceeds;

    TwoKeyEconomy twoKeyEconomy;
    TwoKeyWhitelisted whitelistInfluencer;
    TwoKeyWhitelisted whitelistConverter;

    /// TODO: Difference between price&rate
    uint pricePerUnitInETH = 1; /// There's single price for the unit ERC20
    uint256 public rate = 1; /// rate of conversion from TwoKey to ETH
    //TODO:Where we get RATE?
    uint openingTime;
    uint closingTime;
    address moderator;
    uint256 expiryConversion; /// how long will hold asset in escrow
    uint256 escrowPercentage; /// percentage of payout to. be paid for moderator for escrow

    string public name;
    string public ipfs_hash; // rename to description
    string public symbol;
    uint8 public decimals = 0;  // ARCs are not divisable //TODO: Check if can be deleted
    uint256 public maxReferralRewardPercent = 10; // maxRefferalRewardPercent is actually bonus percentage in ETH
    uint maxConverterBonusPercent; //translates to discount - we can add this to constructor

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

    uint256 unit_decimals;  // units being sold can be fractional (for example tokens in ERC20)


    // Remove contractor from constructor it's the message sender
    constructor(address _twoKeyEventSource, address _twoKeyEconomy,
        address _whitelistInfluencer, address _whitelistConverter,
        address _moderator, uint _openingTime, uint _closingTime,
        uint _expiryConversion, uint _escrowPercentage, uint _rate, uint _maxReferralRewardPercent,
        address _assetContract, uint _quota) TwoKeyCampaignARC(_twoKeyEventSource, _quota) StandardToken()
        public {
            require(_twoKeyEconomy != address(0));
            require(_whitelistInfluencer != address(0));
            require(_whitelistConverter != address(0));
            require(_assetContract != address(0));
            require(_rate > 0);
            require(_maxReferralRewardPercent > 0);

            contractor = msg.sender;
            twoKeyEconomy = TwoKeyEconomy(_twoKeyEconomy);
            whitelistInfluencer = TwoKeyWhitelisted(_whitelistInfluencer);
            whitelistConverter = TwoKeyWhitelisted(_whitelistConverter);
            assetContract = _assetContract;
            moderator = _moderator;
            openingTime = _openingTime;
            closingTime = _closingTime;
            expiryConversion = _expiryConversion;
            escrowPercentage = _escrowPercentage;
            maxReferralRewardPercent = _maxReferralRewardPercent;

            // Emit event that TwoKeyCampaign is created
            twoKeyEventSource.created(address(this),contractor);
    }


    /// @notice Modifier which is going to check if current time is between opening-closing campaign time
    modifier isOngoing() {
        require(block.timestamp >= openingTime && block.timestamp <= closingTime);
        _;
    }

    /// @notice Modifier which is going to check if campaign is closed (if time is greater then closing time)
    modifier isClosed() {
        require(now > closingTime);
        _;
    }

    /// @notice Modifier to check is the influencer eligible for participation in campaign
    modifier isWhiteListedInfluencer() {
        require(whitelistInfluencer.isWhitelisted(msg.sender));
        _;
    }

    /// @notice Modifier to check is the converter eligible for participation in conversion
    modifier isWhitelistedConverter() {
        require(whitelistConverter.isWhitelisted(msg.sender));
        _;
    }


    /// @notice Modifier to check if the Converter did the conversion
    modifier didConverterConvert() {
        Conversion memory c = conversions[msg.sender];
        require(!c.isFulfilled && !c.isCancelled);
        _;
    }


    /// @notice Method to add fungible asset to our contract
    /// @dev When user calls this method, he just says the actual amount of ERC20 he'd like to transfer to us
    /// @param _amount is the amount of ERC20 contract he'd like to give us
    /// @return true if successful, otherwise transaction will revert
    function addFungibleAsset(uint256 _amount) public returns (bool) {
        require(
            assetContract.call(
                bytes4(keccak256("transferFrom(address,address,uint256)")),
                msg.sender,
                address(this),
                _amount
            )
        );
        campaignInventoryUnitsBalance += _amount;
        return true;
    }

    /// @notice Function to check balance of the ERC20 inventory (view - no gas needed to call this function)
    /// @dev we're using Utils contract and fetching the balance of this contract address
    /// @return balance value as uint
    function checkInventoryBalance() public view returns (uint) {
        uint balance = Utils.call_return(assetContract,"balanceOf(address)",uint(this));
        return balance;
    }

    /// @notice Function which will check the balance and automatically update the balance in our contract regarding balance response
    /// @return balance of ERC20 we have in our contract
    function checkAndUpdateInventoryBalance() public returns (uint) {
        uint balance = checkInventoryBalance();
        campaignInventoryUnitsBalance = balance;
        return balance;
    }



    // TODO: Udis code which sends rewards etc get it
    // TODO: Expiry of conversion event (Two-steps for conversion user puts in ether, and converter being approved by KYC)
    // TODO: When conversion happens, there's timeout where converter can be approved, otherwise everything's transfered to contractor



    /**
     * given the total payout, calculates the moderator fee
     * @param  _payout total payout for escrow
     * @return moderator fee
     */
    function calculateModeratorFee(uint256 _payout) internal view returns (uint256)  {
        if (escrowPercentage > 0) { // send the fee to moderator
            uint256 fee = _payout.mul(escrowPercentage).div(100);
            return fee;
        }
        return 0;
    }





    function cancelledEscrow(address _converter, address _assetContract, uint256 _amount) internal {
        Conversion memory c = conversions[_converter];
        c.isCancelled = true;
        conversions[_converter] = c;
        addFungibleAsset(_amount);
        require(twoKeyEconomy.transfer(_converter, (c.payout).mul(rate)));
    }


    function cancelAssetTwoKey(address _converter, string _assetName, address _assetContract, uint256 _amount)  public returns (bool) {
        Conversion memory c = conversions[_converter];
        require(!c.isCancelled && !c.isFulfilled);
        cancelledEscrow(_converter, _assetContract, _amount);
        twoKeyEventSource.cancelled(address(this), _converter, _assetName, _assetContract, _amount, CampaignType.CPA_FUNGIBLE);

        return true;
    }


    //onlyRole(ROLE_CONTROLLER) - comment
    function expireEscrow(address _converter,address _assetContract, uint256 _amount) public returns (bool) {
        Conversion memory c = conversions[_converter];
        require(!c.isCancelled && !c.isFulfilled);
        require(now > c.closingTime);
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

//TODO: DELETE
//    /// @notice (Fallback)Payable function which will accept all transactions which are sending ether to contract
//    /// @dev we require that msg.value is greater than 0
//    /// @dev function will update the mapping balances where we're mapping how much ether has been sent to contract from specified address
//    /// @dev will emit an event with address and value sent
//    function () external payable {
//        require(msg.value > 0);
//        balancesConvertersETH[msg.sender] += msg.value;
//        //        fulfillFungibleETH(from, msg.value);
//        emit ReceivedEther(msg.sender, msg.value);
//    }

    /// @notice Function to check how much eth has been sent to contract from address
    /// @param _from is the address we'd like to check balance
    /// @return amount of ether sent to contract from the specified address
    function checkAmountAddressSent(address _from) public view returns (uint) {
        return balancesConvertersETH[_from];
    }

    /// @notice Function to check contract balance of specified ERC20 tokens
    /// @return balance
    function getContractBalance() public view returns(uint) {
        return campaignInventoryUnitsBalance;
    }

    /// @notice View function to fetch the address of asset contract
    /// @return address of that asset contract
    function getAssetContractAddress() public view returns(address) {
        return assetContract;
    }

//    /// @notice Function to return constantss
//    function getConstantInfo() public view returns (uint256,uint256,uint256,uint256) {
//        return (pricePerUnitInETH, maxReferralRewardPercent,quota,unit_decimals);
//    }
//    function getConstantInfo() public view returns (string,string,uint256,uint256,uint256,address,string,uint256) {
//        return (name,symbol,price,bounty,quota,contractor,ipfs_hash,unit_decimals);
//    }



    // the 2key link generated by the owner of this contract contains a secret which is a private key,
    // this is the public part of this secret
    mapping(address => address)  public public_link_key;

    function setPubLinkWithCut(address _public_link_key, uint256 cut) {
        setPublicLinkKey(_public_link_key);
        setCut(cut);
    }

    /// At the beginning only contractor can call this method bcs he is the only one who has arcs
    function setPublicLinkKey(address _public_link_key) public {
        require(balanceOf(msg.sender) > 0);
        require(public_link_key[msg.sender] == address(0));
        public_link_key[msg.sender] = _public_link_key;
    }

    function setCut(uint256 cut) private {
        // the sender sets what is the percentage of the bounty s/he will receive when acting as an influencer
        // the value 255 is used to signal equal partition with other influencers
        // A sender can set the value only once in a contract
        require(cut <= 100 || cut == 255);
        require(influencer2cut[msg.sender] == 0);
        if (cut <= 100) {
            cut++;
        }
        influencer2cut[msg.sender] = cut;
    }


    function getCuts(address last_influencer) public view returns (uint256[]) {
        address[] memory influencers = getInfluencers(last_influencer);
        uint256[] memory cuts = new uint256[](influencers.length + 1);
        for (uint i = 0; i < influencers.length; i++) {
            address influencer = influencers[i];
            cuts[i] = influencer2cut[influencer];
        }
        cuts[influencers.length] = influencer2cut[last_influencer];
        return cuts;
    }


    /// @notice Transfersig method
    function transferSig(bytes sig) public {
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
        if (idx+20 <= sig.length) {
            idx += 20;
            assembly
            {
                old_address := mload(add(sig, idx))
            }
        }

        address old_public_link_key = public_link_key[old_address];
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
            if (idx + 41 < sig.length) {  // its  a < and not a <= because we don't want this to be the final iteration for the converter
                uint8 bounty_cut;
                //        if (with_cut)
                {
                    idx += 1;
                    assembly
                    {
                        bounty_cut := mload(add(sig, idx))
                    }
                    require(bounty_cut > 0);  // 0 and 255 are used to indicate default (equal part) behaviour
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
                    if (influencer2cut[new_address] == 0) {
                        influencer2cut[new_address] = uint256(bounty_cut);
                    } else {
                        require(influencer2cut[new_address] == uint256(bounty_cut));
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
    function joinAndConvert(bytes sig) public payable {
        /*
        sig is the signature
        */
        ///Signature includes our information which goes to Ethereum
        require(msg.value >= minContribution); //TODO add this field

    transferSig(sig);
        createConversion(msg.value, msg.sender);
    }

    function convert() public payable{
        require(msg.value >= minContribution); //TODO add this field

        require(public_link_key[msg.sender] != address(0));
        createConversion(msg.value, msg.sender);
    }

    //TODO: for paying with external address, the user needs to transfer an ARC to the external address, and then we can call the public default payable
    function () external payable{
        require(msg.value >= minContribution); //TODO add this field

        require(balanceOf(msg.sender) > 0);
        createConversion(msg.value, msg.sender);
    }


    //******************************************************
    //(2) CONVERSION 1st STEP

    /// @notice Function to buy product
    /// @param value is amount of ether sent
    /// @param sender is the sender who's buying
    function createConversion(uint conversionAmountETH, address converterAddress) isOngoing private {
        /*
        (2) We get the ETH amount
        (3) we compute tokens = base + bonus tokens
        (2) We create conversion object
        (2) we can't do anything until converter is whitelisted


        */
        unit_decimals = uint256(assetContract.decimals());  //18; //

        //TODO: calculate this from the conversionAmountETH and maxConverterBonusPercent
        baseTokensForConverter = ?
        bonusTokensForConverter = ?
        _units = baseTokensForConverter + bonusTokensForConverter;

        //        Each token has 10**decimals units
        // TODO: Compute valid base units and bonus units per the msg.value and token price and bonus percentage
        ???? uint256 _units = value.mul(10**unit_decimals).div(rate);
        //uint _units = 1000;
        // we are buying

        uint256 maxReferralRewardETH = maxReferralRewardPercent.mul(_units).div(10**unit_decimals);
        uint256 moderatorFeeETH = calculateModeratorFee(c.payout);

        uint256 contractorProceeds = conversionAmountETH - maxReferralRewardETH - moderatorFeeETH;

        //TODO: what's from?
        //TODO: add moderatorFee, baseTokensAmount, bonusTokensAmount, TotalTokensAmount
        Conversion memory c = Conversion(_from, contractorProceeds, converterAddress, false, false, assetName, assetContract, conversionAmountETH, CampaignType.CPA_FUNGIBLE, now, now + expiryConversion * 1 days);

        // move funds
        campaignInventoryUnitsBalance = campaignInventoryUnitsBalance - _units;

        // value in escrow (msg.value), total amount of tokens
        //        twoKeyEventSource.escrow(address(this), msg.sender, _assetName, _assetContract, _amount, CampaignType.CPA_FUNGIBLE);
        conversions[converterAddress] = c;


    }


    //******************************************************
    //(3) CONVERSION 2nd STEP
    //actually third step after the moderator/contractor approved the converter in the white list

    function executeConversion() isWhitelistedConverter didConverterConvert public {
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

        // Example; MaxReferralReward = 10% then msg.value = 100ETH
        // then this conversionReward = 10ETH
        // TODO: this function has to be part of conversion

        updateRefchainRewards(_units, maxReferralReward);

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
        require(assetContract.call(bytes4(keccak256("transfer(address,uint256)")), converterAddress, _units));




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

        uint256 _total_units = checkInventoryBalance();

        require(_units > 0);
        require(_total_units >= _units);
        address[] memory influencers = getInfluencers(customer);
        //        uint n_influencers = influencers.length;

        // distribute bounty to influencers
        uint256 total_bounty = 0;
        uint max_referral_reward = _bounty.mul(maxReferralRewardPercent).div(100);
        for (uint i = 0; i < influencers.length; i++) {
            uint256 b;
            if (i == influencers.length -1) {  // if its the last influencer then all the bounty goes to it.
                b = _bounty;
            }
            else {
                uint256 cut = influencer2cut[influencers[i]];
                //        emit Log("CUT", influencer, cut);
                if (cut > 0 && cut <= 101) {
                    b = _bounty.mul(cut.sub(1)).mul(maxReferralRewardPercent).div(10000);
                } else {  // cut == 0 or 255 indicates equal particine of the bounty
                    b = _bounty.div(influencers.length -i);
                }
            }
            if(b > max_referral_reward) {
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
            assetContract.call(
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











}
