import createWeb3, {generatePlasmaFromMnemonic} from "./_web3";
import {TwoKeyProtocol} from "../src";
import {expect} from "chai";
import {ICreateCampaign, InvoiceERC20} from "../src/donation/interfaces";
const { env } = process;

const rpcUrl = env.RPC_URL;
const mainNetId = env.MAIN_NET_ID;
const syncTwoKeyNetId = env.SYNC_NET_ID;
const eventsNetUrl = env.PLASMA_RPC_URL;

let twoKeyProtocol: TwoKeyProtocol;
let from: string;

const web3switcher = {
    deployer: () => createWeb3(env.MNEMONIC_DEPLOYER, rpcUrl),
    aydnep: () => createWeb3(env.MNEMONIC_AYDNEP, rpcUrl),
    gmail: () => createWeb3(env.MNEMONIC_GMAIL, rpcUrl),
    test4: () => createWeb3(env.MNEMONIC_TEST4, rpcUrl),
    renata: () => createWeb3(env.MNEMONIC_RENATA, rpcUrl),
    uport: () => createWeb3(env.MNEMONIC_UPORT, rpcUrl),
    gmail2: () => createWeb3(env.MNEMONIC_GMAIL2, rpcUrl),
    aydnep2: () => createWeb3(env.MNEMONIC_AYDNEP2, rpcUrl),
    test: () => createWeb3(env.MNEMONIC_TEST, rpcUrl),
    guest: () => createWeb3('mnemonic words should be here bu   t for some reason they are missing', rpcUrl),
};

const links = {
    deployer: '',
    aydnep: '',
    gmail: '',
    test4: '',
    renata: '',
    uport: '',
    gmail2: '',
    aydnep2: '',
    test: '',
};
/**
 * Donation campaign parameters
 */

let campaignName = 'Donation for Some Services';
let publicMetaHash = 'QmABCDE';
let privateMetaHash = 'QmABCD';
let tokenName = 'NikolaToken';
let tokenSymbol = 'NTKN';
let maxReferralRewardPercent = 5;
let campaignStartTime = 12345;
let campaignEndTime = 1234567;
let minDonationAmount = 10000;
let maxDonationAmount = 10000000000000000000;
let campaignGoal = 100000000000000000000000;
let conversionQuota = 1;
let incentiveModel = 0;

let campaignAddress: string;

//Describe structure of invoice token
let invoiceToken: InvoiceERC20 = {
    tokenName,
    tokenSymbol
};

//Moderator will be AYDNEP in this case
let moderator = env.AYDNEP_ADDRESS;

//Describe initial params and attributes for the campaign

let campaign: ICreateCampaign = {
    moderator,
    campaignName,
    publicMetaHash,
    privateMetaHash,
    invoiceToken,
    maxReferralRewardPercent,
    campaignStartTime,
    campaignEndTime,
    minDonationAmount,
    maxDonationAmount,
    campaignGoal,
    conversionQuota,
    incentiveModel
};

const progressCallback = (name: string, mined: boolean, transactionResult: string): void => {
    console.log(`Contract ${name} ${mined ? `deployed with address ${transactionResult}` : `placed to EVM. Hash ${transactionResult}`}`);
};

describe('TwoKeyDonationCampaign', () => {

   it('should create a donation campaign', async() => {

       const {web3, address} = web3switcher.deployer();
       from = address;
       twoKeyProtocol = new TwoKeyProtocol({
           web3,
           networks: {
               mainNetId,
               syncTwoKeyNetId,
           },
           eventsNetUrl,
           plasmaPK: generatePlasmaFromMnemonic(env.MNEMONIC_DEPLOYER).privateKey,
       });

        campaignAddress = await twoKeyProtocol.DonationCampaign.create(campaign, from, {
            progressCallback,
            gasPrice: 150000000000,
            interval: 500,
            timeout: 600000
        });
   }).timeout(60000);

   it('should proof that campaign is set and validated properly', async() => {
       console.log(campaignAddress);
       let isValidated = await twoKeyProtocol.CampaignValidator.isCampaignValidated(campaignAddress);
       expect(isValidated).to.be.equal(true);
       console.log('Campaign is validated');
   }).timeout(60000);

   it('should proof that non singleton hash is set for the campaign', async() => {
        let nonSingletonHash = await twoKeyProtocol.CampaignValidator.getCampaignNonSingletonsHash(campaignAddress);
        expect(nonSingletonHash).to.be.equal(twoKeyProtocol.AcquisitionCampaign.getNonSingletonsHash());
    }).timeout(60000);

   it('should get contract stored data', async() => {
        let data = await twoKeyProtocol.DonationCampaign.getContractData(campaignAddress);
        console.log(data);
   }).timeout(60000);

   it('should get user public link', async () => {
       try {
           const publicLink = await twoKeyProtocol.DonationCampaign.getPublicLinkKey(campaignAddress, from);
           console.log('User Public Link', publicLink);
           expect(parseInt(publicLink, 16)).to.be.greaterThan(0);
       } catch (e) {
           throw e;
       }
   }).timeout(10000);

   it('should visit campaign as guest', async () => {
       const {web3, address} = web3switcher.guest();
       from = address;
       twoKeyProtocol.setWeb3({
           web3,
           networks: {
               mainNetId,
               syncTwoKeyNetId,
           },
           eventsNetUrl,
           plasmaPK: generatePlasmaFromMnemonic('mnemonic words should be here but for some reason they are missing').privateKey,
       });
       let txHash = await twoKeyProtocol.DonationCampaign.visit(campaignAddress, links.deployer);
       console.log(txHash);
       expect(txHash.length).to.be.gt(0);
    }).timeout(60000);
});