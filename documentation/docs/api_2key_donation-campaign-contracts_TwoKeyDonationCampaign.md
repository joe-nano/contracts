---
id: 2key_donation-campaign-contracts_TwoKeyDonationCampaign
title: TwoKeyDonationCampaign
---

<div class="contract-doc"><div class="contract"><h2 class="contract-header"><span class="contract-kind">contract</span> TwoKeyDonationCampaign</h2><p class="base-contracts"><span>is</span> <a href="2key_campaign-mutual-contracts_TwoKeyCampaign.html">TwoKeyCampaign</a><span>, </span><a href="2key_campaign-mutual-contracts_TwoKeyCampaignIncentiveModels.html">TwoKeyCampaignIncentiveModels</a></p><div class="source">Source: <a href="git+https://github.com/2keynet/web3-alpha/blob/v0.0.3/contracts/2key/donation-campaign-contracts/TwoKeyDonationCampaign.sol" target="_blank">2key/donation-campaign-contracts/TwoKeyDonationCampaign.sol</a></div><div class="author">Author: Nikola Madjarevic Created at 2/19/19</div></div><div class="index"><h2>Index</h2><ul><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#distributeArcsBasedOnSignature">distributeArcsBasedOnSignature</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#distributeReferrerRewards">distributeReferrerRewards</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#donate">donate</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#">fallback</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#">fallback</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#getCampaignData">getCampaignData</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#getDonation">getDonation</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#getReferrers">getReferrers</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#goalValidator">goalValidator</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#isOngoing">isOngoing</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#joinAndDonate">joinAndDonate</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#joinAndShareARC">joinAndShareARC</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#onlyInDonationLimit">onlyInDonationLimit</a></li><li><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#updateReferrerMappings">updateReferrerMappings</a></li></ul></div><div class="reference"><h2>Reference</h2><div class="modifiers"><h3>Modifiers</h3><ul><li><div class="item modifier"><span id="goalValidator" class="anchor-marker"></span><h4 class="name">goalValidator</h4><div class="body"><code class="signature">modifier <strong>goalValidator</strong><span>() </span></code><hr/></div></div></li><li><div class="item modifier"><span id="isOngoing" class="anchor-marker"></span><h4 class="name">isOngoing</h4><div class="body"><code class="signature">modifier <strong>isOngoing</strong><span>() </span></code><hr/></div></div></li><li><div class="item modifier"><span id="onlyInDonationLimit" class="anchor-marker"></span><h4 class="name">onlyInDonationLimit</h4><div class="body"><code class="signature">modifier <strong>onlyInDonationLimit</strong><span>() </span></code><hr/></div></div></li></ul></div><div class="functions"><h3>Functions</h3><ul><li><div class="item function"><span id="distributeArcsBasedOnSignature" class="anchor-marker"></span><h4 class="name">distributeArcsBasedOnSignature</h4><div class="body"><code class="signature">function <strong>distributeArcsBasedOnSignature</strong><span>(bytes signature) </span><span>internal </span></code><hr/><div class="description"><p>Function to unpack signature and distribute arcs so we can keep trace on referrals.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>signature</code> - is the signature containing the whole refchain up to the user</div></dd></dl></div></div></li><li><div class="item function"><span id="distributeReferrerRewards" class="anchor-marker"></span><h4 class="name">distributeReferrerRewards</h4><div class="body"><code class="signature">function <strong>distributeReferrerRewards</strong><span>(address converter, uint totalBountyForConversion) </span><span>internal </span></code><hr/><div class="description"><p>Function to distribute referrer rewards depending on selected model.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>converter</code> - is the address of the converter</div><div><code>totalBountyForConversion</code> - is total bounty for the conversion</div></dd></dl></div></div></li><li><div class="item function"><span id="donate" class="anchor-marker"></span><h4 class="name">donate</h4><div class="body"><code class="signature">function <strong>donate</strong><span>() </span><span>public </span><span>payable </span></code><hr/><div class="description"><p>Function where user has already joined and want to donate.</p></div><dl><dt><span class="label-modifiers">Modifiers:</span></dt><dd><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#goalValidator">goalValidator </a><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#onlyInDonationLimit">onlyInDonationLimit </a><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#isOngoing">isOngoing </a></dd></dl></div></div></li><li><div class="item function"><span id="fallback" class="anchor-marker"></span><h4 class="name">fallback</h4><div class="body"><code class="signature">function <strong></strong><span>() </span><span>public </span><span>payable </span></code><hr/><div class="description"><p>Fallback function to handle input payments -&gt; no referrer rewards in this case.</p></div><dl><dt><span class="label-modifiers">Modifiers:</span></dt><dd><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#goalValidator">goalValidator </a><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#onlyInDonationLimit">onlyInDonationLimit </a><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#isOngoing">isOngoing </a></dd></dl></div></div></li><li><div class="item function"><span id="fallback" class="anchor-marker"></span><h4 class="name">fallback</h4><div class="body"><code class="signature">function <strong></strong><span>(address _moderator, string _campaignName, string _publicMetaHash, string _privateMetaHash, string tokenName, string tokenSymbol, uint _campaignStartTime, uint _campaignEndTime, uint _minDonationAmount, uint _maxDonationAmount, uint _campaignGoal, uint _conversionQuota, address _twoKeySingletonesRegistry, IncentiveModel _rewardsModel) </span><span>public </span></code><hr/><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>_moderator</code> - address</div><div><code>_campaignName</code> - string</div><div><code>_publicMetaHash</code> - string</div><div><code>_privateMetaHash</code> - string</div><div><code>tokenName</code> - string</div><div><code>tokenSymbol</code> - string</div><div><code>_campaignStartTime</code> - uint</div><div><code>_campaignEndTime</code> - uint</div><div><code>_minDonationAmount</code> - uint</div><div><code>_maxDonationAmount</code> - uint</div><div><code>_campaignGoal</code> - uint</div><div><code>_conversionQuota</code> - uint</div><div><code>_twoKeySingletonesRegistry</code> - address</div><div><code>_rewardsModel</code> - IncentiveModel</div></dd></dl></div></div></li><li><div class="item function"><span id="getCampaignData" class="anchor-marker"></span><h4 class="name">getCampaignData</h4><div class="body"><code class="signature">function <strong>getCampaignData</strong><span>() </span><span>public </span><span>view </span><span>returns  (bytes) </span></code><hr/><dl><dt><span class="label-return">Returns:</span></dt><dd>bytes</dd></dl></div></div></li><li><div class="item function"><span id="getDonation" class="anchor-marker"></span><h4 class="name">getDonation</h4><div class="body"><code class="signature">function <strong>getDonation</strong><span>(uint donationId) </span><span>public </span><span>view </span><span>returns  (bytes) </span></code><hr/><div class="description"><p>Function to read donation.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>donationId</code> - is the id of donation</div></dd><dt><span class="label-return">Returns:</span></dt><dd>bytes</dd></dl></div></div></li><li><div class="item function"><span id="getReferrers" class="anchor-marker"></span><h4 class="name">getReferrers</h4><div class="body"><code class="signature">function <strong>getReferrers</strong><span>(address converter) </span><span>public </span><span>view </span><span>returns  (address[]) </span></code><hr/><div class="description"><p>Function to get all referrers participated in conversion.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>converter</code> - is the converter (one who did the action and ended ref chain)</div></dd><dt><span class="label-return">Returns:</span></dt><dd>array of addresses (plasma) of influencers</dd></dl></div></div></li><li><div class="item function"><span id="joinAndDonate" class="anchor-marker"></span><h4 class="name">joinAndDonate</h4><div class="body"><code class="signature">function <strong>joinAndDonate</strong><span>(bytes signature) </span><span>public </span><span>payable </span></code><hr/><div class="description"><p>Function where user can join to campaign and donate funds.</p></div><dl><dt><span class="label-modifiers">Modifiers:</span></dt><dd><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#goalValidator">goalValidator </a><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#onlyInDonationLimit">onlyInDonationLimit </a><a href="2key_donation-campaign-contracts_TwoKeyDonationCampaign.html#isOngoing">isOngoing </a></dd><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>signature</code> - is signature he&#x27;s joining with</div></dd></dl></div></div></li><li><div class="item function"><span id="joinAndShareARC" class="anchor-marker"></span><h4 class="name">joinAndShareARC</h4><div class="body"><code class="signature">function <strong>joinAndShareARC</strong><span>(bytes signature, address receiver) </span><span>public </span></code><hr/><div class="description"><p>Function to join with signature and share 1 arc to the receiver.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>signature</code> - is the signature generated</div><div><code>receiver</code> - is the address we&#x27;re sending ARCs to</div></dd></dl></div></div></li><li><div class="item function"><span id="updateReferrerMappings" class="anchor-marker"></span><h4 class="name">updateReferrerMappings</h4><div class="body"><code class="signature">function <strong>updateReferrerMappings</strong><span>(address referrerPlasma, uint reward) </span><span>internal </span></code><hr/><div class="description"><p>Internal function to update referrer mappings with value.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>referrerPlasma</code> - is referrer plasma address</div><div><code>reward</code> - is the reward referrer earned</div></dd></dl></div></div></li></ul></div></div></div>