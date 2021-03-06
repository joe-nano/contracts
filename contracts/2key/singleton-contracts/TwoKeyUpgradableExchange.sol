pragma solidity ^0.4.24;


import "../ERC20/ERC20.sol";

import "../interfaces/ITwoKeyExchangeRateContract.sol";
import "../interfaces/ITwoKeyCampaignValidator.sol";
import "../interfaces/IKyberNetworkProxy.sol";
import "../interfaces/storage-contracts/ITwoKeyUpgradableExchangeStorage.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IBancorContract.sol";
import "../interfaces/ITwoKeyFeeManager.sol";
import "../interfaces/ITwoKeyReg.sol";
import "../interfaces/ITwoKeyEventSource.sol";

import "../upgradability/Upgradeable.sol";


import "../libraries/SafeMath.sol";
import "../libraries/GetCode.sol";
import "../libraries/PriceDiscovery.sol";

import "../non-upgradable-singletons/ITwoKeySingletonUtils.sol";


contract TwoKeyUpgradableExchange is Upgradeable, ITwoKeySingletonUtils {

    using SafeMath for uint256;

    bool initialized;
    address constant ETH_TOKEN_ADDRESS = 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee;

    string constant _twoKeyCampaignValidator = "TwoKeyCampaignValidator";
    string constant _twoKeyEconomy = "TwoKeyEconomy";
    string constant _twoKeyExchangeRateContract = "TwoKeyExchangeRateContract";
    string constant _twoKeyAdmin = "TwoKeyAdmin";
    string constant _dai = "DAI";
    string constant _kyberNetworkProxy = "KYBER_NETWORK_PROXY";


    ITwoKeyUpgradableExchangeStorage public PROXY_STORAGE_CONTRACT;

    /**
     * @notice          Event for token purchase logging
     *
     * @param           purchaser who paid for the tokens
     * @param           receiver is who got the tokens
     * @param           weiReceived is how weis paid for purchase
     * @param           tokensBought is the amount of tokens purchased
     * @param           rate is the global variable rate on the contract
     */
    event TokenPurchase(
        address indexed purchaser,
        address indexed receiver,
        uint256 weiReceived,
        uint256 tokensBought,
        uint256 rate
    );


    /**
     * @notice          This event will be fired every time a withdraw is executed
     */
    event WithdrawExecuted(
        address caller,
        address beneficiary,
        uint stableCoinsReserveBefore,
        uint stableCoinsReserveAfter,
        uint etherBalanceBefore,
        uint etherBalanceAfter,
        uint stableCoinsToWithdraw,
        uint twoKeyAmount
    );


    event HedgedEther (
        uint _daisReceived,
        uint _ratio,
        uint _numberOfContracts
    );

    event DAI2KEYSwapped(
        uint _daisSent,
        uint _twoKeyReceived
    );

    /**
     * @notice          Constructor of the contract, can be called only once
     *
     * @param           _daiAddress is the address of DAI on ropsten
     * @param           _kyberNetworkProxyAddress is the address of Kyber network contract
     * @param           _twoKeySingletonesRegistry is the address of TWO_KEY_SINGLETON_REGISTRY
     * @param           _proxyStorageContract is the address of proxy of storage contract
     */
    function setInitialParams(
        address _daiAddress,
        address _kyberNetworkProxyAddress,
        address _twoKeySingletonesRegistry,
        address _proxyStorageContract
    )
    external
    {
        require(initialized == false);

        TWO_KEY_SINGLETON_REGISTRY = _twoKeySingletonesRegistry;
        PROXY_STORAGE_CONTRACT = ITwoKeyUpgradableExchangeStorage(_proxyStorageContract);
        setUint(keccak256("spreadWei"), 3**16); // 3% wei
        // 0.06$ Wei
        setUint(keccak256("sellRate2key"),6 * (10**16));// When anyone send Ether to contract, 2key in exchange will be calculated on it's sell rate
        setUint(keccak256("weiRaised"),0);
        setUint(keccak256("numberOfContracts"), 0); //Number of contracts which have interacted with this contract through buyTokens function

        setAddress(keccak256(_dai), _daiAddress);
        setAddress(keccak256(_kyberNetworkProxy), _kyberNetworkProxyAddress);

        initialized = true;
    }


    /**
     * @notice          Modifier which will validate if contract is allowed to buy tokens
     */
    modifier onlyValidatedContracts {
        address twoKeyCampaignValidator = getAddressFromTwoKeySingletonRegistry(_twoKeyCampaignValidator);
        require(ITwoKeyCampaignValidator(twoKeyCampaignValidator).isCampaignValidated(msg.sender) == true);
        _;
    }


    /**
     * @notice          Modifier which will validate if msg sender is TwoKeyAdmin contract
     */
    modifier onlyTwoKeyAdmin {
        address twoKeyAdmin = getAddressFromTwoKeySingletonRegistry(_twoKeyAdmin);
        require(msg.sender == twoKeyAdmin);
        _;
    }


    /**
     * @dev             Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
     *                  Use `super` in contracts that inherit from Crowdsale to extend their validations.
     *
     * @param           _beneficiary Address performing the token purchase
     * @param           _weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(
        address _beneficiary,
        uint256 _weiAmount
    )
    private
    {
        require(_beneficiary != address(0),'beneficiary address can not be 0' );
        require(_weiAmount != 0, 'wei amount can not be 0');
    }


    /**
     * @dev             Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
     * @param           _beneficiary Address performing the token purchase
     * @param           _tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(
        address _beneficiary,
        uint256 _tokenAmount
    )
    internal
    {
        //Take the address of token from storage
        address tokenAddress = getNonUpgradableContractAddressFromTwoKeySingletonRegistry(_twoKeyEconomy);
        ERC20(tokenAddress).transfer(_beneficiary, _tokenAmount);
    }


    /**
     * @dev             Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
     * @param           _beneficiary Address receiving the tokens
     * @param           _tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(
        address _beneficiary,
        uint256 _tokenAmount
    )
    internal
    {
        _deliverTokens(_beneficiary, _tokenAmount);
    }


    /**
     * @notice          Function to calculate how much pnercentage will be deducted from values
     */
    function calculatePercentageToDeduct(
        uint _ethWeiHedged,
        uint _sumOfAmounts
    )
    internal
    view
    returns (uint)
    {
        return _ethWeiHedged.mul(10**18).div(_sumOfAmounts);
    }


    /**
     * @notice          Function to calculate ratio between eth and dai in WEI's
     */
    function calculateRatioBetweenDAIandETH(
        uint _ethWeiHedged,
        uint _daiReceived
    )
    internal
    view
    returns (uint)
    {
        return _daiReceived.mul(10**18).div(_ethWeiHedged);
    }


    /**
     * @notice          Setter for EthWeiAvailableToHedge
     * @param           _contractID is the ID of the contract
     * @param           _msgValue is the amount sent
     */
    function updateEthWeiAvailableToHedge(
        uint _contractID,
        uint _msgValue
    )
    internal {
        // Update EthWeiAvailableToHedge per contract
        bytes32 ethWeiAvailableToHedgeKeyHash = keccak256("ethWeiAvailableToHedge", _contractID);
        setUint(ethWeiAvailableToHedgeKeyHash, getUint(ethWeiAvailableToHedgeKeyHash).add(_msgValue));
    }


    /**
     * @notice          Function to register new contract with corresponding ID
     * @param           _contractAddress is the address of the contract we're adding
     */
    function addNewContract(
        address _contractAddress
    )
    internal
    returns (uint)
    {
        // Get number of currently different contracts and increment by 1
        uint numberOfContractsExisting = numberOfContracts();
        uint id = numberOfContractsExisting.add(1);

        bytes32 keyHashContractAddressToId = keccak256("contractAddressToId", _contractAddress);
        bytes32 keyHashIdToContractAddress = keccak256("idToContractAddress", id);

        // Set mappings id=>contractAddress and contractAddress=>id
        setUint(keyHashContractAddressToId, id);
        setAddress(keyHashIdToContractAddress, _contractAddress);

        // Increment number of existing contracts
        setUint(keccak256("numberOfContracts"), id);

        // Return contract ID
        return id;
    }


    /**
     * @notice          Function to emit an event, created separately because of stack depth
     */
    function emitEventWithdrawExecuted(
        address _beneficiary,
        uint _stableCoinsOnContractBefore,
        uint _stableCoinsAfter,
        uint _etherBalanceOnContractBefore,
        uint _stableCoinUnits,
        uint twoKeyUnits
    )
    internal
    {
        emit WithdrawExecuted(
            msg.sender,
            _beneficiary,
            _stableCoinsOnContractBefore,
            _stableCoinsAfter,
            _etherBalanceOnContractBefore,
            this.balance,
            _stableCoinUnits,
            twoKeyUnits
        );
    }


    /**
     * @notice          Internal function to get uint from storage contract
     *
     * @param           key is the to which value is allocated in storage
     */
    function getUint(
        bytes32 key
    )
    internal
    view
    returns (uint)
    {
        return PROXY_STORAGE_CONTRACT.getUint(key);
    }


    /**
     * @notice          Internal function to set uint on the storage contract
     *
     * @param           key is the key to which value is (will be) allocated in storage
     * @param           value is the value (uint) we're saving in the state
     */
    function setUint(
        bytes32 key,
        uint value
    )
    internal
    {
        PROXY_STORAGE_CONTRACT.setUint(key, value);
    }


    /**
     * @notice          Internal function to get bool from storage contract
     *
     * @param           key is the to which value is allocated in storage
     */
    function getBool(
        bytes32 key
    )
    internal
    view
    returns (bool)
    {
        return PROXY_STORAGE_CONTRACT.getBool(key);
    }


    /**
     * @notice          Internal function to set boolean on the storage contract
     *
     * @param           key is the key to which value is (will be) allocated in storage
     * @param           value is the value (boolean) we're saving in the state
     */
    function setBool(
        bytes32 key,
        bool value
    )
    internal
    {
        PROXY_STORAGE_CONTRACT.setBool(key,value);
    }


    /**
     * @notice          Internal function to get address from storage contract
     *
     * @param           key is the to which value is allocated in storage
     */
    function getAddress(
        bytes32 key
    )
    internal
    view
    returns (address)
    {
        return PROXY_STORAGE_CONTRACT.getAddress(key);
    }


    /**
     * @notice          Internal function to set address on the storage contract
     *
     * @param           key is the key to which value is (will be) allocated in storage
     * @param           value is the value (address) we're saving in the state
     */
    function setAddress(
        bytes32 key,
        address value
    )
    internal
    {
        PROXY_STORAGE_CONTRACT.setAddress(key, value);
    }


    /**
     * @notice          Function to get eth received from contract for specific contract ID
     *
     * @param           _contractID is the ID of the contract we're requesting information
     */
    function ethReceivedFromContract(
        uint _contractID
    )
    internal
    view
    returns (uint)
    {
        return getUint(keccak256("ethReceivedFromContract", _contractID));
    }


    /**
     * @notice          Function to get how many 2keys are sent to selected contract
     *
     * @param           _contractID is the ID of the contract we're requesting information
     */
    function sent2keyToContract(
        uint _contractID
    )
    internal
    view
    returns (uint)
    {
        return getUint(keccak256("sent2keyToContract", _contractID));
    }


    /**
     * @notice          Function to get how much ethWei hedged per contract
     *
     * @param           _contractID is the ID of the contract we're requesting information
     */
    function ethWeiHedgedPerContract(
        uint _contractID
    )
    internal
    view
    returns (uint)
    {
        return getUint(keccak256("ethWeiHedgedPerContract", _contractID));
    }


    /**
     * @notice          Function to determine how many dai received from hedging per contract
     *
     * @param           _contractID is the ID of the contract we're requesting information
     */
    function daiWeiReceivedFromHedgingPerContract(
        uint _contractID
    )
    internal
    view
    returns (uint)
    {
        return getUint(keccak256("daiWeiReceivedFromHedgingPerContract", _contractID));
    }


    /**
     * @notice          Function to report that 2KEY tokens are withdrawn from the network
     *
     * @param           amountOfTokensWithdrawn is the amount of tokens he wants to withdraw
     * @param           _contractID is the id of the contract
     */
    function report2KEYWithdrawnFromNetworkInternal(
        uint amountOfTokensWithdrawn,
        uint _contractID
    )
    internal
    {
        bytes32 _daiWeiAvailableToWithdrawKeyHash = keccak256("daiWeiAvailableToWithdraw",_contractID);
        bytes32 _daiWeiAvailableToFill2KEYReserveKeyHash = keccak256("daiWeiAvailableToFill2KEYReserve");

        uint _daiWeiAvailable = daiWeiAvailableToWithdraw(_contractID);
        uint _daiWeiToReduceFromAvailableAndFillReserve = getUSDStableCoinAmountFrom2keyUnits(amountOfTokensWithdrawn, _contractID);

        uint _daiWeiAvailableToFill2keyReserveCurrently = daiWeiAvailableToFill2KEYReserve();

        setUint(_daiWeiAvailableToFill2KEYReserveKeyHash, _daiWeiAvailableToFill2keyReserveCurrently.add(_daiWeiToReduceFromAvailableAndFillReserve));
        setUint(_daiWeiAvailableToWithdrawKeyHash, _daiWeiAvailable.sub(_daiWeiToReduceFromAvailableAndFillReserve));

        // Emit the event that DAI is released
        ITwoKeyEventSource(getAddressFromTwoKeySingletonRegistry("TwoKeyEventSource")).emitDAIReleasedAsIncome(
            msg.sender,
            _daiWeiToReduceFromAvailableAndFillReserve
        );
    }


    /**
     * @notice          Internal function created to update specific values, separated because of stack depth
     *
     * @param           _daisReceived is the amount of received dais
     * @param           _hedgedEthWei is the amount of ethWei hedged
     * @param           _afterHedgingAvailableEthWei is the amount available after hedging
     * @param           _contractID is the ID of the contract
     */
    function updateAccountingValues(
        uint _daisReceived,
        uint _hedgedEthWei,
        uint _afterHedgingAvailableEthWei,
        uint _contractID
    )
    internal
    {
        bytes32 ethWeiAvailableToHedgeKeyHash = keccak256("ethWeiAvailableToHedge", _contractID);
        bytes32 daiWeiAvailableToWithdrawKeyHash = keccak256("daiWeiAvailableToWithdraw", _contractID);
        bytes32 ethWeiHedgedPerContractKeyHash = keccak256("ethWeiHedgedPerContract", _contractID);
        bytes32 daiWeiReceivedFromHedgingPerContractKeyHash = keccak256("daiWeiReceivedFromHedgingPerContract",_contractID);

        setUint(daiWeiReceivedFromHedgingPerContractKeyHash, daiWeiReceivedFromHedgingPerContract(_contractID).add(_daisReceived));
        setUint(ethWeiHedgedPerContractKeyHash, ethWeiHedgedPerContract(_contractID).add(_hedgedEthWei));
        setUint(ethWeiAvailableToHedgeKeyHash, _afterHedgingAvailableEthWei);
        setUint(daiWeiAvailableToWithdrawKeyHash, daiWeiAvailableToWithdraw(_contractID).add(_daisReceived));
    }

    /**
     * @notice          Function to reduce amount of dai available to be withdrawn from selected contract
     *
     * @param           contractAddress is the address of the contract
     * @param           daiAmount is the amount of dais
     */
    function reduceDaiWeiAvailableToWithdraw(
        address contractAddress,
        uint daiAmount
    )
    internal
    {
        uint contractId = getContractId(contractAddress);
        bytes32 keyHashDaiWeiAvailableToWithdraw = keccak256('daiWeiAvailableToWithdraw', contractId);
        PROXY_STORAGE_CONTRACT.setUint(keyHashDaiWeiAvailableToWithdraw, daiWeiAvailableToWithdraw(contractId).sub(daiAmount));
    }


    /**
     * @notice          Function to pay Fees to a manager and transfer the tokens forward to the referrers
     *
     * @param           _beneficiary is the address who's receiving tokens
     * @param           _contractId is the id of the contract
     * @param           _totalStableCoins is the total amount of DAIs
     */
    function payFeesToManagerAndTransferTokens(
        address _beneficiary,
        uint _contractId,
        uint _totalStableCoins,
        ERC20 dai
    )
    internal
    {
        address _userPlasma = ITwoKeyReg(getAddressFromTwoKeySingletonRegistry("TwoKeyRegistry")).getEthereumToPlasma(_beneficiary);
        // Handle if there's any existing debt
        address twoKeyFeeManager = getAddressFromTwoKeySingletonRegistry("TwoKeyFeeManager");
        uint usersDebtInEth = ITwoKeyFeeManager(twoKeyFeeManager).getDebtForUser(_userPlasma);
        uint amountToPay = 0;

        if(usersDebtInEth > 0) {
            uint eth2DAI = getEth2DaiAverageExchangeRatePerContract(_contractId); // DAI / ETH
            uint totalDebtInDAI = (usersDebtInEth.mul(eth2DAI)).div(10**18); // ETH * (DAI/ETH) = DAI

            amountToPay = totalDebtInDAI;

            if (_totalStableCoins > totalDebtInDAI){
                if(_totalStableCoins < 3 * totalDebtInDAI) {
                    amountToPay = totalDebtInDAI / 2;
                }
            }
            else {
                amountToPay = _totalStableCoins / 4;
            }

            dai.transfer(twoKeyFeeManager, amountToPay);
            ITwoKeyFeeManager(twoKeyFeeManager).payDebtWithDAI(_userPlasma, totalDebtInDAI, amountToPay);
        }

        dai.transfer(_beneficiary, _totalStableCoins.sub(amountToPay)); // Transfer the rest of the DAI to users
    }


    /**
     * @notice          Function to calculate available to hedge sum on all contracts
     */
    function calculateSumOnContracts(
        uint startIndex,
        uint endIndex
    )
    public
    view
    returns (uint)
    {
        uint sumOfAmounts = 0; //Will represent total sum we have on the contract
        uint i;

        // Sum all amounts on all contracts
        for(i=startIndex; i<=endIndex; i++) {
            sumOfAmounts = sumOfAmounts.add(ethWeiAvailableToHedge(i));
        }
        return sumOfAmounts;
    }


    /**
     * @notice          Function to get contract id, if return 0 means contract is not existing
     */
    function getContractId(
        address _contractAddress
    )
    public
    view
    returns (uint) {
        bytes32 keyHashContractAddressToId = keccak256("contractAddressToId", _contractAddress);
        uint id = getUint(keyHashContractAddressToId);
        return id;
    }


    /**
     * @notice          Function to get amount of the tokens user will receive
     *
     * @param           _weiAmount Value in wei to be converted into tokens
     *
     * @return          Number of tokens that can be purchased with the specified _weiAmount
     */
    function getTokenAmountToBeSold(
        uint256 _weiAmount
    )
    public
    view
    returns (uint256,uint256,uint256)
    {
        address twoKeyExchangeRateContract = getAddressFromTwoKeySingletonRegistry(_twoKeyExchangeRateContract);

        uint rate = ITwoKeyExchangeRateContract(twoKeyExchangeRateContract).getBaseToTargetRate("USD");
        uint dollarAmountWei = _weiAmount.mul(rate).div(10**18);

        return get2KEYTokenPriceAndAmountOfTokensReceiving(dollarAmountWei);

    }


    /**
     * @notice          Function to calculate how many stable coins we can get for specific amount of 2keys
     *
     * @dev             This is happening in case we're receiving (buying) 2key
     *
     * @param           _2keyAmount is the amount of 2keys sent to the contract
     * @param           _campaignID is the ID of the campaign
     */
    function getUSDStableCoinAmountFrom2keyUnits(
        uint256 _2keyAmount,
        uint _campaignID
    )
    public
    view
    returns (uint256)
    {
        uint activeHedgeRate = get2KEY2DAIHedgedRate(_campaignID);

        uint hundredPercent = 10**18;
        uint rateWithSpread = activeHedgeRate.mul(hundredPercent.sub(spreadWei())).div(10**18);
        uint amountOfDAIs = _2keyAmount.mul(rateWithSpread).div(10**18);

        return amountOfDAIs;
    }



    function getMore2KeyTokensForRebalancing(
        uint amountOf2KeyRequested
    )
    public
    onlyValidatedContracts
    {
        uint campaignID = getContractId(msg.sender);
        //TODO: Check there's enough 2key and DAI to complete tx
        // Get key for how much DAI is available for this contract to withdraw
        bytes32 _daiWeiAvailableToWithdrawKeyHash = keccak256("daiWeiAvailableToWithdraw", campaignID);
        // Get key for total available to fill reserve
        bytes32 _daiWeiAvailableToFill2KEYReserveKeyHash = keccak256("daiWeiAvailableToFill2KEYReserve");

        // Get DAI available
        uint _daiWeiAvailableToWithdrawAndFillReserve = daiWeiAvailableToWithdraw(campaignID);

        uint _daiWeiAvailableToFill2keyReserveCurrently = daiWeiAvailableToFill2KEYReserve();

        setUint(_daiWeiAvailableToFill2KEYReserveKeyHash, _daiWeiAvailableToFill2keyReserveCurrently.add(_daiWeiAvailableToWithdrawAndFillReserve));

        // Set DAI available for this campaign to 0 since we will release everything to reserve
        setUint(_daiWeiAvailableToWithdrawKeyHash, 0);

        // Send the tokens to the campaign
        _processPurchase(msg.sender, amountOf2KeyRequested);

        // Emit the event that DAI is released
        ITwoKeyEventSource(getAddressFromTwoKeySingletonRegistry("TwoKeyEventSource")).emitDAIReleasedAsIncome(
            msg.sender,
            _daiWeiAvailableToWithdrawAndFillReserve
        );
    }


    /**
     * @notice          Function to buyTokens from TwoKeyUpgradableExchange
     * @param           _beneficiary is the address which will receive the tokens
     * @return          amount of tokens bought
     */
    function buyTokens(
        address _beneficiary
    )
    public
    payable
    onlyValidatedContracts
    returns (uint,uint)
    {
        _preValidatePurchase(_beneficiary, msg.value);

        uint totalTokensBought;
        uint averageTokenPriceForPurchase;
        uint newTokenPrice;

        (totalTokensBought, averageTokenPriceForPurchase, newTokenPrice) = getTokenAmountToBeSold(msg.value);

        // update sellRate2KEY of the token
        bytes32 sellRateKeyHash = keccak256("sellRate2key");

        // Set the new token price after this purchase
        setUint(sellRateKeyHash, newTokenPrice);

        // update weiRaised by this contract
        bytes32 weiRaisedKeyHash = keccak256("weiRaised");
        uint weiRaised = getUint(weiRaisedKeyHash).add(msg.value);
        setUint(weiRaisedKeyHash,weiRaised);

        // check if contract is first time interacting with this one
        uint contractId = getContractId(msg.sender);

        // Check if the contract exists
        if(contractId == 0) {
            contractId = addNewContract(msg.sender);
        }

        // Update how much ether we received from msg.sender contract
        bytes32 ethReceivedFromContractKeyHash = keccak256("ethReceivedFromContract", contractId);
        setUint(ethReceivedFromContractKeyHash, ethReceivedFromContract(contractId).add(msg.value));

        // Update how much 2KEY tokens we sent to msg.sender contract
        bytes32 sent2keyToContractKeyHash = keccak256("sent2keyToContract", contractId);
        setUint(sent2keyToContractKeyHash, sent2keyToContract(contractId).add(totalTokensBought));

        updateEthWeiAvailableToHedge(contractId, msg.value);

        _processPurchase(_beneficiary, totalTokensBought);


        emit TokenPurchase(
            msg.sender,
            _beneficiary,
            msg.value,
            totalTokensBought,
            averageTokenPriceForPurchase
        );

        return (totalTokensBought, averageTokenPriceForPurchase);
    }


    function releaseAllDAIFromContractToReserve()
    public
    onlyValidatedContracts
    {
        uint _contractID = getContractId(msg.sender);
        bytes32 _daiWeiAvailableToWithdrawKeyHash = keccak256("daiWeiAvailableToWithdraw",_contractID);
        bytes32 _daiWeiAvailableToFill2KEYReserveKeyHash = keccak256("daiWeiAvailableToFill2KEYReserve");

        uint _daiWeiAvailableToWithdrawAndFillReserve = daiWeiAvailableToWithdraw(_contractID);

        uint _daiWeiAvailableToFill2keyReserveCurrently = daiWeiAvailableToFill2KEYReserve();

        setUint(_daiWeiAvailableToFill2KEYReserveKeyHash, _daiWeiAvailableToFill2keyReserveCurrently.add(_daiWeiAvailableToWithdrawAndFillReserve));
        setUint(_daiWeiAvailableToWithdrawKeyHash, 0);

        // Emit the event that DAI is released
        ITwoKeyEventSource(getAddressFromTwoKeySingletonRegistry("TwoKeyEventSource")).emitDAIReleasedAsIncome(
            msg.sender,
            _daiWeiAvailableToWithdrawAndFillReserve
        );

    }

    /**
     * @notice          Function which will be called every time by campaign when referrer select to withdraw directly 2key token
     *
     * @param           amountOfTokensWithdrawn is the amount of tokens he wants to withdraw
     */
    function report2KEYWithdrawnFromNetwork(
        uint amountOfTokensWithdrawn
    )
    public
    onlyValidatedContracts
    {
        uint _contractID = getContractId(msg.sender);
        if(ethReceivedFromContract(_contractID) > 0 ) {
            report2KEYWithdrawnFromNetworkInternal(amountOfTokensWithdrawn, _contractID);
        }
    }


    /**
     * @notice          After the rebalancing on budget campaigns is done, we're releasing all the DAI tokens
     *
     * @param           amountOf2key is the amount of 2key which we're receiving back to liquidity pool
     */
    function returnLeftoverAfterRebalancing(
        uint amountOf2key
    )
    public
    onlyValidatedContracts
    {
        uint contractID = getContractId(msg.sender);

        bytes32 _daiWeiAvailableToWithdrawKeyHash = keccak256("daiWeiAvailableToWithdraw",contractID);
        bytes32 _daiWeiAvailableToFill2KEYReserveKeyHash = keccak256("daiWeiAvailableToFill2KEYReserve");

        uint _daiWeiAvailableToWithdrawAndFillReserve = daiWeiAvailableToWithdraw(contractID);
        uint _daiWeiAvailableToFill2keyReserveCurrently = daiWeiAvailableToFill2KEYReserve();

        setUint(_daiWeiAvailableToFill2KEYReserveKeyHash, _daiWeiAvailableToFill2keyReserveCurrently.add(_daiWeiAvailableToWithdrawAndFillReserve));
        setUint(_daiWeiAvailableToWithdrawKeyHash, 0);

        //Take 2key tokens to the liquidity pool
        IERC20(getNonUpgradableContractAddressFromTwoKeySingletonRegistry(_twoKeyEconomy)).transferFrom(
            msg.sender,
            address(this),
            amountOf2key
        );

        // Emit the event that DAI is released
        ITwoKeyEventSource(getAddressFromTwoKeySingletonRegistry("TwoKeyEventSource")).emitDAIReleasedAsIncome(
            msg.sender,
            _daiWeiAvailableToWithdrawAndFillReserve
        );
    }


    /**
     * @notice          Function to get expected rate from Kyber contract
     * @param           amountEthWei is the amount we'd like to exchange
     * @return          if the value is 0 that means we can't
     */
    function getKyberExpectedRate(
        uint amountEthWei
    )
    public
    view
    returns (uint)
    {
        address kyberProxyContract = getAddress(keccak256(_kyberNetworkProxy));
        IKyberNetworkProxy proxyContract = IKyberNetworkProxy(kyberProxyContract);

        ERC20 eth = ERC20(ETH_TOKEN_ADDRESS);
        ERC20 dai = ERC20(getAddress(keccak256(_dai)));

        uint minConversionRate;
        (minConversionRate,) = proxyContract.getExpectedRate(eth, dai, amountEthWei);

        return minConversionRate;
    }


    /**
     * @notice          Function to get expected rate from Kyber contract for swapping DAI to 2KEY
     * @param           amountDAIWei is the amount of dais we want to swap
     * @param           dai is DAI token
     * @param           twoKeyToken is ERC20 2KEY token
     */
    function getKyberExpectedRateDAI2KEY(
        uint amountDAIWei,
        ERC20 dai,
        ERC20 twoKeyToken
    )
    public
    view
    returns (uint)
    {
        address kyberProxyContract = getAddress(keccak256(_kyberNetworkProxy));
        IKyberNetworkProxy proxyContract = IKyberNetworkProxy(kyberProxyContract);

        uint minConversionRate;
        (minConversionRate,) = proxyContract.getExpectedRate(dai,twoKeyToken, amountDAIWei);

        return minConversionRate;
    }


    /**
     * @notice          Function to start hedging some ether amount
     * @param           amountToBeHedged is the amount we'd like to hedge
     * @dev             only maintainer can call this function
     */
    function startHedging(
        uint amountToBeHedged,
        uint approvedMinConversionRate
    )
    public
    onlyMaintainer
    {
        ERC20 dai = ERC20(getAddress(keccak256(_dai)));
        if(amountToBeHedged > address(this).balance) {
            amountToBeHedged = address(this).balance;
        }
        address kyberProxyContract = getAddress(keccak256(_kyberNetworkProxy));
        IKyberNetworkProxy proxyContract = IKyberNetworkProxy(kyberProxyContract);

        uint minConversionRate = getKyberExpectedRate(amountToBeHedged);
        require(minConversionRate >= approvedMinConversionRate.mul(95).div(100)); //Means our rate can be at most same as their rate, because they're giving the best rate
        uint stableCoinUnits = proxyContract.swapEtherToToken.value(amountToBeHedged)(dai,minConversionRate);
        // Get the ratio between ETH and DAI for this hedging
        uint ratio = calculateRatioBetweenDAIandETH(amountToBeHedged, stableCoinUnits);
        //Emit event with important data
        emit HedgedEther(stableCoinUnits, ratio, numberOfContracts());
    }

    /**
     * @notice          Function to send available DAI to Kyber and get 2KEY tokens
     *
     * @param           amountOfDAIToSwap is the amount of DAI tokens we want to swap
     * @param           approvedMinConversionRate is the approved minimal conversion rate we can get
     */
    function swapDaiAvailableToFillReserveFor2KEY(
        uint amountOfDAIToSwap,
        uint approvedMinConversionRate
    )
    public
    onlyTwoKeyAdmin
    {
        // Generate the key hash for dai available to fill 2KEY reserve
        bytes32 _daiWeiAvailableToFill2KEYReserveKeyHash = keccak256("daiWeiAvailableToFill2KEYReserve");

        // Get amount of DAI available for this operation
        uint daiWeiAvailableToFill2KEYReserve = getUint(_daiWeiAvailableToFill2KEYReserveKeyHash);

        // Require that we have more than enough dai's to perform this swap
        require(daiWeiAvailableToFill2KEYReserve >= amountOfDAIToSwap);

        // Get and instantiate kyber proxy contract
        address kyberProxyContract = getAddress(keccak256(_kyberNetworkProxy));
        IKyberNetworkProxy proxyContract = IKyberNetworkProxy(kyberProxyContract);

        // Instantiate dai and 2KEY token
        ERC20 dai = ERC20(getAddress(keccak256(_dai)));
        ERC20 twoKeyToken = ERC20(getNonUpgradableContractAddressFromTwoKeySingletonRegistry(_twoKeyEconomy));

        // Get minConversionRate from Kyber
        uint minConversionRate = getKyberExpectedRateDAI2KEY(amountOfDAIToSwap, dai, twoKeyToken);

        // Allow at most 5% spread
        require(minConversionRate >= approvedMinConversionRate.mul(95).div(100));

        // Approve kyberProxyContract to take DAIs
        dai.approve(kyberProxyContract, amountOfDAIToSwap);

        // Perform swap and account how many 2KEY tokens received
        uint received2KEYTokens = proxyContract.swapTokenToToken(dai, amountOfDAIToSwap, twoKeyToken, minConversionRate);

        // Update DAI tokens available to fill reserve
        setUint(_daiWeiAvailableToFill2KEYReserveKeyHash, daiWeiAvailableToFill2KEYReserve.sub(amountOfDAIToSwap));

        emit DAI2KEYSwapped(amountOfDAIToSwap, received2KEYTokens);
    }

    function calculateHedgedAndReceivedForDefinedChunk(
        uint numberOfContractsCurrently,
        uint amountHedged,
        uint stableCoinsReceived,
        uint startIndex,
        uint endIndex
    )
    public
    view
    returns (uint,uint)
    {
        //We're calculating sum on contracts between start and end index
        uint sumInRange = calculateSumOnContracts(startIndex,endIndex);
        //Now we need how much was hedged from this contracts between start and end index
        uint stableCoinsReceivedForThisChunkOfContracts = (sumInRange.mul(stableCoinsReceived)).div(amountHedged);
        // Returning for this piece of contracts
        return (sumInRange, stableCoinsReceivedForThisChunkOfContracts);
    }

    /**
     * @notice          Function to reduce available amount to hedge and increase available DAI to withdraw
     *
     * @param           _ethWeiHedgedForThisChunk is how much eth was hedged
     * @param           _daiReceivedForThisChunk is how much DAI's we got for that hedging
     */
    function reduceHedgedAmountFromContractsAndIncreaseDaiAvailable(
        uint _ethWeiHedgedForThisChunk,
        uint _daiReceivedForThisChunk,
        uint _ratio,
        uint _startIndex,
        uint _endIndex
    )
    public
    onlyMaintainer
    {
        uint i;
        uint percentageToDeductWei = calculatePercentageToDeduct(_ethWeiHedgedForThisChunk, _ethWeiHedgedForThisChunk); // Percentage to deduct in WEI (less than 1)

        for(i=_startIndex; i<=_endIndex; i++) {
            if(ethWeiAvailableToHedge(i) > 0) {
                uint beforeHedgingAvailableEthWeiForContract = ethWeiAvailableToHedge(i);
                uint hundredPercentWei = 10**18;
                uint afterHedgingAvailableEthWei = beforeHedgingAvailableEthWeiForContract.mul(hundredPercentWei.sub(percentageToDeductWei)).div(10**18);

                uint hedgedEthWei = beforeHedgingAvailableEthWeiForContract.sub(afterHedgingAvailableEthWei);
                uint daisReceived = hedgedEthWei.mul(_ratio).div(10**18);
                updateAccountingValues(daisReceived, hedgedEthWei, afterHedgingAvailableEthWei, i);
            }
        }
    }


    /**
     * @notice          Function which will be called by 2key campaigns if user wants to withdraw his earnings in stableCoins
     *
     * @param           _twoKeyUnits is the amount of 2key tokens which will be taken from campaign
     * @param           _beneficiary is the user who will receive the tokens
     */
    function buyStableCoinWith2key(
        uint _twoKeyUnits,
        address _beneficiary
    )
    public
    onlyValidatedContracts
    {
        ERC20 dai = ERC20(getAddress(keccak256(_dai)));
        ERC20 token = ERC20(getNonUpgradableContractAddressFromTwoKeySingletonRegistry(_twoKeyEconomy));

        uint contractId = getContractId(msg.sender); // Get the contract ID

        uint stableCoinUnits = getUSDStableCoinAmountFrom2keyUnits(_twoKeyUnits, contractId); // Calculate how much stable coins he's getting
        uint etherBalanceOnContractBefore = this.balance; // get ether balance on contract
        uint stableCoinsOnContractBefore = dai.balanceOf(address(this)); // get dai balance on contract

        reduceDaiWeiAvailableToWithdraw(msg.sender, stableCoinUnits); // reducing amount of DAI available for withdrawal

        emitEventWithdrawExecuted(
            _beneficiary,
            stableCoinsOnContractBefore,
            stableCoinsOnContractBefore.sub(stableCoinUnits),
            etherBalanceOnContractBefore,
            stableCoinUnits,
            _twoKeyUnits
        );

        token.transferFrom(msg.sender, address(this), _twoKeyUnits); //Take all 2key tokens from campaign contract
        payFeesToManagerAndTransferTokens(_beneficiary, contractId, stableCoinUnits, dai);
    }




    /**
     * @notice          Function to buy 2key tokens from Bancor
     *
     * @param           amountDAI we're willing to send (daiWeiAvailableToFill2keyReserve)
     * @param           amount2KEY the minimum amount of 2KEY that is acceptable in return
     */
    function buy2KEYFromBancor(
        uint amountDAI,
        uint amount2KEY
    )
    public
    payable
    onlyMaintainer
    {
        // Firstly we need to approve Bancor converter to take tokens from us
        address dai = getAddress(keccak256(_dai));
        address bancorConverter = getAddress(keccak256("BANCOR_CONVERTER"));
        address bancorToken = getAddress(keccak256("BNT"));
        address twoKeyEconomy = getNonUpgradableContractAddressFromTwoKeySingletonRegistry(_twoKeyEconomy);
        // Approving bancor to take tokens from US
        ERC20(dai).approve(bancorConverter, amountDAI);

        // We need to create path
        IERC20[] memory path = new IERC20[](5);
        path[0] = IERC20(dai);
        path[1] = IERC20(bancorToken);
        path[2] = IERC20(bancorToken);
        path[3] = IERC20(twoKeyEconomy);
        path[4] = IERC20(twoKeyEconomy);

        uint receivedTokens = IBancorContract(bancorConverter).quickConvert(path, amountDAI, amount2KEY);

        bytes32 daiWeiAvailablbeToFill2keyReserveKeyHash = keccak256("daiWeiAvailableToFill2KEYReserve");
        setUint(daiWeiAvailablbeToFill2keyReserveKeyHash, daiWeiAvailableToFill2KEYReserve().sub(amountDAI));
    }


    /**
     * @notice          Function to return number of campaign contracts (different) interacted with this contract
     */
    function numberOfContracts() public view returns (uint) {
        return getUint(keccak256("numberOfContracts"));
    }


    /**
     * @notice          Function to get 2key to DAI hedged rate
     *
     * @param           _contractID is the ID of the contract we're fetching this rate (avg)
     */
    function get2KEY2DAIHedgedRate(
        uint _contractID
    )
    public
    view
    returns (uint)
    {
        /**
            (dai/eth) / (2key/eth)  =
            (dai * eth)  / (2key *eth) =
             dai / 2key
        */
        return getEth2DaiAverageExchangeRatePerContract(_contractID).mul(10**18).div(getEth2KeyAverageRatePerContract(_contractID));
    }

    /**
     * @notice          Function to get Eth2DAI average exchange rate per contract
     *
     * @param           _contractID is the ID of the contract we're requesting information
     */
    function getEth2DaiAverageExchangeRatePerContract(
        uint _contractID
    )
    public
    view
    returns (uint)
    {
        uint ethWeiHedgedPerContractByNow = ethWeiHedgedPerContract(_contractID); //total hedged
        uint daiWeiReceivedFromHedgingPerContractByNow = daiWeiReceivedFromHedgingPerContract(_contractID); //total received
        // Average weighted by eth
        return daiWeiReceivedFromHedgingPerContractByNow.mul(10**18).div(ethWeiHedgedPerContractByNow); //dai/eth
    }


    /**
     * @notice          Function to get Eth22key average exchange rate per contract
     *
     * @param           _contractID is the ID of the contract we're requesting information
     */
    function getEth2KeyAverageRatePerContract(
        uint _contractID
    )
    public
    view
    returns (uint)
    {
        uint ethReceivedFromContractByNow = ethReceivedFromContract(_contractID);
        uint sent2keyToContractByNow = sent2keyToContract(_contractID);
        // Average weighted by eth 2key/eth
        return sent2keyToContractByNow.mul(10**18).div(ethReceivedFromContractByNow);
    }


    function daiWeiAvailableToFill2KEYReserve()
    public
    view
    returns (uint)
    {
        return getUint(keccak256("daiWeiAvailableToFill2KEYReserve"));
    }


    /**
     * @notice          Getter for mapping "daiWeiAvailableToWithdraw" (per contract)
     */
    function daiWeiAvailableToWithdraw(
        uint _contractID
    )
    public
    view
    returns (uint)
    {
        return getUint(keccak256("daiWeiAvailableToWithdraw", _contractID));
    }

    /**
     * @notice          Getter for "mapping" ethWeiAvailableToHedge (per contract)
     */
    function ethWeiAvailableToHedge(
        uint _contractID
    )
    public
    view
    returns (uint)
    {
        return getUint(keccak256("ethWeiAvailableToHedge", _contractID));
    }

    /**
     * @notice          Getter wrapping all information about income/outcome for every contract
     * @param           _contractAddress is the main campaign address
     */
    function getAllStatsForContract(
        address _contractAddress
    )
    public
    view
    returns (uint,uint,uint,uint,uint,uint)
    {
        uint _contractID = getContractId(_contractAddress);
        return (
            ethWeiAvailableToHedge(_contractID),
            daiWeiAvailableToWithdraw(_contractID),
            daiWeiReceivedFromHedgingPerContract(_contractID),
            ethWeiHedgedPerContract(_contractID),
            sent2keyToContract(_contractID),
            ethReceivedFromContract(_contractID)
        );
    }


    /**
     * @notice          Getter function to check if campaign has been hedged ever
     *                  Assuming that this function regarding flow will be called at point where there must be
     *                  executed conversions, and in that case, if there are no any ETH received from contract,
     *                  that means that this campaign is not hedgeable
     *
     * @param _contractAddress is the campaign address
     */
    function isCampaignHedgeable(
        address _contractAddress
    )
    public
    view
    returns (bool)
    {
        uint _contractID = getContractId(_contractAddress);
        return ethReceivedFromContract(_contractID) > 0 ? true : false;
    }


    function poolWorthUSD()
    public
    view
    returns (uint)
    {
        // 1.08 M Dollars in WEI
        return 1080000*(10**18);
    }


    /**
     * @notice          Getter to get spreadWei value
     */
    function spreadWei()
    public
    view
    returns (uint)
    {
        return getUint(keccak256("spreadWei"));
    }

    /**
     * @notice          Getter for 2key sell rate
     */
    function sellRate2key()
    public
    view
    returns (uint)
    {
        return getUint(keccak256("sellRate2key"));
    }

    /**
     * @notice          Getter for weiRaised
     */
    function weiRaised()
    public
    view
    returns (uint)
    {
        return getUint(keccak256("weiRaised"));
    }

    /**
     * @notice          Withdraw all ether from contract
     */
    function withdrawEther()
    public
    onlyTwoKeyAdmin
    {
        (msg.sender).transfer(address(this).balance);
    }


    /**
     * @notice          Function to withdraw any ERC20 tokens to TwoKeyAdmin
     */
    function withdrawERC20(
        address _erc20TokenAddress,
        uint _tokenAmount
    )
    public
    onlyTwoKeyAdmin
    {
        ERC20(_erc20TokenAddress).transfer(msg.sender, _tokenAmount);
    }

    /**
     * @notice          Function to get current pool supply of 2KEY tokens
     */
    function getPoolBalanceOf2KeyTokens()
    public
    view
    returns (uint)
    {
        address tokenAddress = getNonUpgradableContractAddressFromTwoKeySingletonRegistry(_twoKeyEconomy);
        return ERC20(tokenAddress).balanceOf(address(this));
    }

    /**
     * @notice          Function to get amount of 2KEY receiving, new token price, and average price per token
     *
     * @param           purchaseAmountUSDWei is the amount of USD user is spending to buy tokens
     */
    function get2KEYTokenPriceAndAmountOfTokensReceiving(
         uint purchaseAmountUSDWei
    )
    public
    view
    returns (uint,uint,uint)
    {
        uint currentPrice = sellRate2key();

        return PriceDiscovery.buyTokensFromExchangeRealignPrice(
            purchaseAmountUSDWei,
            currentPrice,
            getPoolBalanceOf2KeyTokens(),
            poolWorthUSD()
        );
    }

    /**
     * @notice          Function to get token price from the Bancor exchange
     */
    function getBancorPriceFor2KeyToken(
        uint purchaseAmountUSDWei
    )
    public
    view
    returns (uint)
    {
        //TODO: For now return 0, once Bancor integrated we will update this function
        return 0;
    }


    /**
     * @notice          Fallback function to handle incoming ether
     */
    function ()
    public
    payable
    {

    }

}
