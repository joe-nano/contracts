import {ITwoKeyBase, ITwoKeyHelpers, ITwoKeyUtils} from '../interfaces';
import {promisify} from '../utils/promisify'
import Sign from '../sign';
import {IPlasmaEvents, ISignedEthereum, IVisits, IVisitsAndJoins} from "./interfaces";

export default class PlasmaEvents implements IPlasmaEvents {
    private readonly base: ITwoKeyBase;
    private readonly helpers: ITwoKeyHelpers;
    private readonly utils: ITwoKeyUtils;

    constructor(twoKeyProtocol: ITwoKeyBase, helpers: ITwoKeyHelpers, utils: ITwoKeyUtils) {
        this.base = twoKeyProtocol;
        this.helpers = helpers;
        this.utils = utils;
    }

    /**
     *
     * @param {string} plasma
     * @returns {Promise<string>}
     */
    public getRegisteredAddressForPlasma(plasma: string = this.base.plasmaAddress): Promise<string> {
        return this.helpers._awaitPlasmaMethod(promisify(this.base.twoKeyPlasmaEvents.plasma2ethereum, [plasma]))
    }

    /**
     *
     * @returns {Promise<string>}
     */
    public signReferrerToWithdrawRewards(): Promise<string> {
        return Sign.sign_referrerWithPlasma(this.base.plasmaWeb3, this.base.plasmaAddress, 'WITHDRAW_REFERRER_REWARDS');
    }

    /**
     *
     * @returns {Promise<string>}
     */
    public signReferrerToGetRewards(): Promise<string> {
        return Sign.sign_referrerWithPlasma(this.base.plasmaWeb3, this.base.plasmaAddress, 'GET_REFERRER_REWARDS');
    }

    /**
     *
     * @param {string} from
     * @returns {Promise<string>}
     */
    public signPlasmaToEthereum(from: string, force?: string): Promise<ISignedEthereum> {
        return new Promise<ISignedEthereum>(async (resolve, reject) => {
            console.log('PLASMA.signPlasmaToEthereum', from);
            try {
                let plasmaAddress = this.base.plasmaAddress;
                let storedEthAddress;
                if (!force) {
                    storedEthAddress = await this.helpers._awaitPlasmaMethod(this.getRegisteredAddressForPlasma(plasmaAddress));
                    console.log('PLASMA.signPlasmaToEthereum storedETHAddress', storedEthAddress);
                }
                if (force || storedEthAddress != from) {
                    let plasma2ethereumSignature = await Sign.sign_plasma2ethereum(this.base.web3, plasmaAddress, from);
                    resolve({
                        plasmaAddress,
                        plasma2ethereumSignature
                    });
                } else {
                    reject(new Error('Already registered!'));
                }

            } catch (e) {
                reject(e);
            }
        })
    }

    /**
     *
     * @param {string} campaignAddress
     * @returns {Promise<number>}
     */
    public getVisitsPerCampaign(campaignAddress: string) : Promise<number> {
        return new Promise<number>(async(resolve,reject) => {
            try {
                let numberOfVisits = await promisify(this.base.twoKeyPlasmaEvents.campaign2numberOfVisits,[campaignAddress]);
                resolve(numberOfVisits);
            } catch (e) {
                reject(e);
            }
        })
    }

    /**
     * Function to get number of forwarders per campaign
     * @param {string} campaignAddress
     * @returns {Promise<number>}
     */
    public getForwardersPerCampaign(campaignAddress: string) : Promise<number> {
        return new Promise<number>(async(resolve,reject) => {
            try {
                let numberOfForwards = await promisify(this.base.twoKeyPlasmaEvents.campaign2numberOfForwarders,[campaignAddress]);
                resolve(numberOfForwards);
            } catch (e) {
                reject(e);
            }
        })
    }

    /**
     *
     * @param {string} from
     * @returns {Promise<string>}
     */
    public setPlasmaToEthereumOnPlasma(plasmaAddress: string, plasma2EthereumSignature: string): Promise<string> {
        return new Promise<string>(async (resolve, reject) => {
            try {
                let txHash = await this.helpers._awaitPlasmaMethod(promisify(this.base.twoKeyPlasmaEvents.add_plasma2ethereum, [
                    plasmaAddress,
                    plasma2EthereumSignature,
                    {
                        from: this.base.plasmaAddress
                    }]));
                resolve(txHash);
            } catch (e) {
                reject(e);
            }
        })
    }

    /**
     *
     * @param {string} campaignAddress
     * @param {string} contractorAddress
     * @param {string} address
     * @returns {Promise<IVisits>}
     */
    public getVisitsList(campaignAddress: string, contractorAddress: string, address: string): Promise<IVisits> {
        return new Promise<IVisits>(async (resolve, reject) => {
            try {
                let [visits, timestamps] = await this.helpers._awaitPlasmaMethod(promisify(this.base.twoKeyPlasmaEvents.visitsListEx, [campaignAddress, contractorAddress, address]));
                resolve({
                    visits,
                    timestamps: timestamps.map(time => time * 1000),
                });
            } catch (e) {
                reject(e);
            }
        })
    }

    /**
     *
     * @param {string} campaignAddress
     * @returns {Promise<>}
     */
    public getNumberOfVisitsAndJoins(campaignAddress: string) : Promise<IVisitsAndJoins> {
        return new Promise<IVisitsAndJoins>(async(resolve,reject) => {
            try {
                let [visits,joins] = await this.helpers._awaitPlasmaMethod(promisify(this.base.twoKeyPlasmaEvents.getNumberOfVisitsAndJoinsPerCampaign,[campaignAddress]));
                resolve({
                    visits,
                    joins
                });
            } catch (e) {
                reject(e);
            }
        })
    }

    /**
     *
     * @param {string} campaignAddress
     * @param {string} contractorAddress
     * @param {string} address
     * @returns {Promise<string>}
     */
    public getVisitedFrom(campaignAddress: string, contractorAddress: string, address: string): Promise<string> {
        return new Promise<string>(async (resolve, reject) => {
            try {
                let visitedFrom = this.helpers._awaitPlasmaMethod(promisify(this.base.twoKeyPlasmaEvents.getVisitedFrom, [campaignAddress, contractorAddress, address]));
                resolve(visitedFrom);
            } catch (e) {
                reject(e);
            }
        })
    }

    /**
     *
     * @param {string} campaignAddress
     * @param {string} contractorAddress
     * @param {string} address
     * @returns {Promise<string>}
     */
    public getJoinedFrom(campaignAddress: string, contractorAddress: string, address: string): Promise<string> {
        return new Promise<string>(async (resolve, reject) => {
            try {
                let joinedFrom = this.helpers._awaitPlasmaMethod(promisify(this.base.twoKeyPlasmaEvents.getJoinedFrom, [campaignAddress, contractorAddress, address]));
                resolve(joinedFrom);
            } catch (e) {
                reject(e);
            }
        })
    }
}