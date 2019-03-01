---
id: 2key_singleton-contracts_TwoKeyCampaignValidator
title: TwoKeyCampaignValidator
---

<div class="contract-doc"><div class="contract"><h2 class="contract-header"><span class="contract-kind">contract</span> TwoKeyCampaignValidator</h2><p class="base-contracts"><span>is</span> <a href="2key_Upgradeable.html">Upgradeable</a><span>, </span><a href="2key_MaintainingPattern.html">MaintainingPattern</a></p><div class="source">Source: <a href="git+https://github.com/2keynet/web3-alpha/blob/v0.0.3/contracts/2key/singleton-contracts/TwoKeyCampaignValidator.sol" target="_blank">2key/singleton-contracts/TwoKeyCampaignValidator.sol</a></div><div class="author">Author: Nikola Madjarevic Created at 2/12/19</div></div><div class="index"><h2>Index</h2><ul><li><a href="2key_singleton-contracts_TwoKeyCampaignValidator.html#addValidBytecodes">addValidBytecodes</a></li><li><a href="2key_singleton-contracts_TwoKeyCampaignValidator.html#isConversionHandlerCodeValid">isConversionHandlerCodeValid</a></li><li><a href="2key_singleton-contracts_TwoKeyCampaignValidator.html#removeBytecode">removeBytecode</a></li><li><a href="2key_singleton-contracts_TwoKeyCampaignValidator.html#setInitialParams">setInitialParams</a></li><li><a href="2key_singleton-contracts_TwoKeyCampaignValidator.html#stringToBytes32">stringToBytes32</a></li><li><a href="2key_singleton-contracts_TwoKeyCampaignValidator.html#validateAcquisitionCampaign">validateAcquisitionCampaign</a></li><li><a href="2key_singleton-contracts_TwoKeyCampaignValidator.html#validateDonationCampaign">validateDonationCampaign</a></li></ul></div><div class="reference"><h2>Reference</h2><div class="functions"><h3>Functions</h3><ul><li><div class="item function"><span id="addValidBytecodes" class="anchor-marker"></span><h4 class="name">addValidBytecodes</h4><div class="body"><code class="signature">function <strong>addValidBytecodes</strong><span>(address[] contracts, bytes32[] names) </span><span>public </span></code><hr/><div class="description"><p>Only maintainer can issue calls to this function, Function to add valid bytecodes for the contracts.</p></div><dl><dt><span class="label-modifiers">Modifiers:</span></dt><dd><a href="2key_MaintainingPattern.html#onlyMaintainer">onlyMaintainer </a></dd><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>contracts</code> - is the array of contracts (deployed)</div><div><code>names</code> - is the array of hexed contract names</div></dd></dl></div></div></li><li><div class="item function"><span id="isConversionHandlerCodeValid" class="anchor-marker"></span><h4 class="name">isConversionHandlerCodeValid</h4><div class="body"><code class="signature">function <strong>isConversionHandlerCodeValid</strong><span>(address _conversionHandler) </span><span>public </span><span>view </span><span>returns  (bool) </span></code><hr/><div class="description"><p>Function to validate if specific conversion handler code is valid.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>_conversionHandler</code> - is the address of already deployed conversion handler</div></dd><dt><span class="label-return">Returns:</span></dt><dd>true if code is valid and responds to conversion handler contract</dd></dl></div></div></li><li><div class="item function"><span id="removeBytecode" class="anchor-marker"></span><h4 class="name">removeBytecode</h4><div class="body"><code class="signature">function <strong>removeBytecode</strong><span>(bytes _bytecode) </span><span>public </span></code><hr/><div class="description"><p>Function to remove bytecode of the contract from whitelisted ones.</p></div><dl><dt><span class="label-modifiers">Modifiers:</span></dt><dd><a href="2key_MaintainingPattern.html#onlyMaintainer">onlyMaintainer </a></dd><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>_bytecode</code> - bytes</div></dd></dl></div></div></li><li><div class="item function"><span id="setInitialParams" class="anchor-marker"></span><h4 class="name">setInitialParams</h4><div class="body"><code class="signature">function <strong>setInitialParams</strong><span>(address _twoKeySingletoneRegistry, address[] _maintainers) </span><span>public </span></code><hr/><div class="description"><p>Function to set initial parameters in this contract.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>_twoKeySingletoneRegistry</code> - is the address of TwoKeySingletoneRegistry contract</div><div><code>_maintainers</code> - is the array of initial maintainer addresses</div></dd></dl></div></div></li><li><div class="item function"><span id="stringToBytes32" class="anchor-marker"></span><h4 class="name">stringToBytes32</h4><div class="body"><code class="signature">function <strong>stringToBytes32</strong><span>(string source) </span><span>internal </span><span>pure </span><span>returns  (bytes32) </span></code><hr/><div class="description"><p>Pure function to convert input string to hex.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>source</code> - is the input string</div></dd><dt><span class="label-return">Returns:</span></dt><dd>bytes32</dd></dl></div></div></li><li><div class="item function"><span id="validateAcquisitionCampaign" class="anchor-marker"></span><h4 class="name">validateAcquisitionCampaign</h4><div class="body"><code class="signature">function <strong>validateAcquisitionCampaign</strong><span>(address campaign, string nonSingletonHash) </span><span>public </span></code><hr/><div class="description"><p>Validates all the required stuff, if the campaign is not validated, it can&#x27;t update our singletones, Function which is in charge to validate if the campaign contract is ready It should be called by contractor after he finish all the stuff necessary for campaign to work.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>campaign</code> - is the address of the campaign, in this particular case it&#x27;s acquisition</div><div><code>nonSingletonHash</code> - string</div></dd></dl></div></div></li><li><div class="item function"><span id="validateDonationCampaign" class="anchor-marker"></span><h4 class="name">validateDonationCampaign</h4><div class="body"><code class="signature">function <strong>validateDonationCampaign</strong><span>(address campaign, string nonSingletoneHash) </span><span>public </span></code><hr/><div class="description"><p>Validates all the required stuff, if the campaign is not validated, it can&#x27;t update our singletones, Function to validate Donation campaign if it is ready.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>campaign</code> - is the campaign address</div><div><code>nonSingletoneHash</code> - string</div></dd></dl></div></div></li></ul></div></div></div>