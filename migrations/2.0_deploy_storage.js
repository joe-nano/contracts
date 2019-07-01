const TwoKeyUpgradableExchangeStorage = artifacts.require('TwoKeyUpgradableExchangeStorage');
const TwoKeyCampaignValidatorStorage = artifacts.require('TwoKeyCampaignValidatorStorage');
const TwoKeyEventSourceStorage = artifacts.require("TwoKeyEventSourceStorage");
const TwoKeyAdminStorage = artifacts.require('TwoKeyAdminStorage');
const TwoKeyFactoryStorage = artifacts.require('TwoKeyFactoryStorage');
const TwoKeyMaintainersRegistryStorage = artifacts.require('TwoKeyMaintainersRegistryStorage');
const TwoKeyExchangeRateStorage = artifacts.require('TwoKeyExchangeRateStorage');
const TwoKeyBaseReputationRegistryStorage = artifacts.require('TwoKeyBaseReputationRegistryStorage');
const TwoKeyCommunityTokenPoolStorage = artifacts.require('TwoKeyCommunityTokenPoolStorage');
const TwoKeyDeepFreezeTokenPoolStorage = artifacts.require('TwoKeyDeepFreezeTokenPoolStorage');
const TwoKeyLongTermTokenPoolStorage = artifacts.require('TwoKeyLongTermTokenPoolStorage');
const TwoKeyRegistryStorage = artifacts.require('TwoKeyRegistryStorage');
const TwoKeyPlasmaEventsStorage = artifacts.require('TwoKeyPlasmaEventsStorage');

module.exports = function deploy(deployer) {
    if(deployer.network.startsWith('public') || deployer.network.startsWith('dev')) {
        deployer.deploy(TwoKeyCampaignValidatorStorage)
            .then(() => TwoKeyCampaignValidatorStorage.deployed())
            .then(() => deployer.deploy(TwoKeyUpgradableExchangeStorage))
            .then(() => TwoKeyUpgradableExchangeStorage.deployed())
            .then(() => deployer.deploy(TwoKeyEventSourceStorage))
            .then(() => TwoKeyEventSourceStorage.deployed())
            .then(() => deployer.deploy(TwoKeyAdminStorage))
            .then(() => TwoKeyAdminStorage.deployed())
            .then(() => deployer.deploy(TwoKeyFactoryStorage))
            .then(() => TwoKeyFactoryStorage.deployed())
            .then(() => deployer.deploy(TwoKeyMaintainersRegistryStorage))
            .then(() => TwoKeyMaintainersRegistryStorage.deployed())
            .then(() => deployer.deploy(TwoKeyExchangeRateStorage))
            .then(() => TwoKeyExchangeRateStorage.deployed())
            .then(() => deployer.deploy(TwoKeyBaseReputationRegistryStorage))
            .then(() => TwoKeyBaseReputationRegistryStorage.deployed())
            .then(() => deployer.deploy(TwoKeyCommunityTokenPoolStorage))
            .then(() => TwoKeyCommunityTokenPoolStorage.deployed())
            .then(() => deployer.deploy(TwoKeyDeepFreezeTokenPoolStorage))
            .then(() => TwoKeyDeepFreezeTokenPoolStorage.deployed())
            .then(() => deployer.deploy(TwoKeyLongTermTokenPoolStorage))
            .then(() => TwoKeyLongTermTokenPoolStorage.deployed())
            .then(() => deployer.deploy(TwoKeyRegistryStorage))
            .then(() => TwoKeyRegistryStorage.deployed())
            .then(() => true);
    } else if (eployer.network.startsWith('plasma') || deployer.network.startsWith('private') {
        deployer.deploy(TwoKeyPlasmaEventsStorage)
            .then(() => TwoKeyPlasmaEventsStorage.deployed())
            .then(() => true);
    } else {
        console.log('No deployment configuration for selected network');
    }

};
