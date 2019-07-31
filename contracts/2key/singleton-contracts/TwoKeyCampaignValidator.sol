pragma solidity ^0.4.24;

import "../libraries/GetCode.sol";

import "../interfaces/ITwoKeyAcquisitionCampaignERC20.sol";
import "../interfaces/ITwoKeyEventSourceEvents.sol";
import "../interfaces/ITwoKeyCampaignPublicAddresses.sol";
import "../interfaces/ITwoKeyDonationCampaign.sol";
import "../interfaces/ITwoKeyDonationCampaignFetchAddresses.sol";
import "../interfaces/IGetImplementation.sol";
import "../interfaces/IStructuredStorage.sol";
import "../interfaces/storage-contracts/ITwoKeyCampaignValidatorStorage.sol";

import "../upgradability/Upgradeable.sol";
import "./ITwoKeySingletonUtils.sol";


/**
 * @author Nikola Madjarevic
 * Created at 2/12/19
 */
contract TwoKeyCampaignValidator is Upgradeable, ITwoKeySingletonUtils {

    bool initialized;

    ITwoKeyCampaignValidatorStorage public PROXY_STORAGE_CONTRACT;

    /**
     * @notice Function to set initial parameters in this contract
     * @param _twoKeySingletoneRegistry is the address of TwoKeySingletoneRegistry contract
     * @param _proxyStorage is the address of proxy of storage contract
     */
    function setInitialParams(
        address _twoKeySingletoneRegistry,
        address _proxyStorage
    )
    public
    {
        require(initialized == false);

        TWO_KEY_SINGLETON_REGISTRY = _twoKeySingletoneRegistry;
        PROXY_STORAGE_CONTRACT = ITwoKeyCampaignValidatorStorage(_proxyStorage);

        initialized = true;
    }

    // Modifier which will make function throw if caller is not TwoKeyFactory proxy contract
    modifier onlyTwoKeyFactory {
        address twoKeyFactory = getAddressFromTwoKeySingletonRegistry("TwoKeyFactory");
        require(msg.sender == twoKeyFactory);
        _;
    }

    /**
     * @notice Function which will make newly created campaign validated
     * @param campaign is the address of the campaign
     * @param nonSingletonHash is the non singleton hash at the moment of campaign creation
     */
    function validateAcquisitionCampaign(
        address campaign,
        string nonSingletonHash
    )
    public
    onlyTwoKeyFactory
    {
        address conversionHandler = ITwoKeyAcquisitionCampaignERC20(campaign).conversionHandler();
        address logicHandler = ITwoKeyAcquisitionCampaignERC20(campaign).twoKeyAcquisitionLogicHandler();

        PROXY_STORAGE_CONTRACT.setBool(keccak256("isCampaignValidated", conversionHandler), true);
        PROXY_STORAGE_CONTRACT.setBool(keccak256("isCampaignValidated", logicHandler), true);
        PROXY_STORAGE_CONTRACT.setBool(keccak256("isCampaignValidated",campaign), true);
        PROXY_STORAGE_CONTRACT.setString(keccak256("campaign2NonSingletonHash",campaign), nonSingletonHash);

        emitCreatedEvent(campaign);
    }

    /**
     * @notice Function which will make newly created campaign validated
     * @param campaign is the campaign address
     * @dev Validates all the required stuff, if the campaign is not validated, it can't update our singletones
     */
    function validateDonationCampaign(
        address campaign,
        address donationConversionHandler,
        address donationLogicHandler,
        string nonSingletonHash
    )
    public
    onlyTwoKeyFactory
    {
        PROXY_STORAGE_CONTRACT.setBool(keccak256("isCampaignValidated",campaign), true);
        PROXY_STORAGE_CONTRACT.setBool(keccak256("isCampaignValidated",donationConversionHandler), true);
        PROXY_STORAGE_CONTRACT.setBool(keccak256("isCampaignValidated",donationLogicHandler), true);

        PROXY_STORAGE_CONTRACT.setString(keccak256("campaign2NonSingletonHash",campaign), nonSingletonHash);

        emitCreatedEvent(campaign);
    }


    /**
     * @notice Function which will return either is or not one of the campaign contracts validated
     * @param campaign is any contract deployed during any campaign creation through TwoKeyFactory
     */
    function isCampaignValidated(address campaign) public view returns (bool) {
        bytes32 hashKey = keccak256("isCampaignValidated", campaign);
        return PROXY_STORAGE_CONTRACT.getBool(hashKey);
    }

    /**
     * @notice Function which is serving as getter for non-singleton hash at the time of campaign creation
     * @param campaign is the address of strictly main campaign contract (TwoKeyAcquisitionCampaignERC20, TwoKeyDonationCampaign for now)
     */
    function campaign2NonSingletonHash(address campaign) public view returns (string) {
        return PROXY_STORAGE_CONTRACT.getString(keccak256("campaign2NonSingletonHash", campaign));
    }

    /**
     * @notice Function to emit event on TwoKeyEventSource contract
     */
    function emitCreatedEvent(address campaign) internal {
        address contractor = ITwoKeyCampaignPublicAddresses(campaign).contractor();
        address moderator = ITwoKeyCampaignPublicAddresses(campaign).moderator();

        //Get the event source address
        address twoKeyEventSource = getAddressFromTwoKeySingletonRegistry("TwoKeyEventSource");
        // Emit event
        ITwoKeyEventSourceEvents(twoKeyEventSource).created(campaign,contractor,moderator);
    }
}
