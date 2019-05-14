export interface ITwoKeyCampaignValidator {
    validateCampaign: (campaignAddress: string, nonSingletonHash: string, from:string) => Promise<string>,
    isCampaignValidated: (campaignAddress:string) => Promise<boolean>,
    getCampaignNonSingletonsHash: (campaignAddress:string) => Promise<string>,
}