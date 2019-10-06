---
id: openzeppelin-solidity_contracts_crowdsale_distribution_PostDeliveryCrowdsale
title: PostDeliveryCrowdsale
---

<div class="contract-doc"><div class="contract"><h2 class="contract-header"><span class="contract-kind">contract</span> PostDeliveryCrowdsale</h2><p class="base-contracts"><span>is</span> <a href="openzeppelin-solidity_contracts_crowdsale_validation_TimedCrowdsale.html">TimedCrowdsale</a></p><p class="description">Crowdsale that locks tokens from withdrawal until it ends.</p><div class="source">Source: <a href="https://github.com/2keynet/web3-alpha/blob/v0.0.3/contracts/openzeppelin-solidity/contracts/crowdsale/distribution/PostDeliveryCrowdsale.sol" target="_blank">contracts/openzeppelin-solidity/contracts/crowdsale/distribution/PostDeliveryCrowdsale.sol</a></div></div><div class="index"><h2>Index</h2><ul><li><a href="openzeppelin-solidity_contracts_crowdsale_distribution_PostDeliveryCrowdsale.html#_processPurchase">_processPurchase</a></li><li><a href="openzeppelin-solidity_contracts_crowdsale_distribution_PostDeliveryCrowdsale.html#withdrawTokens">withdrawTokens</a></li></ul></div><div class="reference"><h2>Reference</h2><div class="functions"><h3>Functions</h3><ul><li><div class="item function"><span id="_processPurchase" class="anchor-marker"></span><h4 class="name">_processPurchase</h4><div class="body"><code class="signature">function <strong>_processPurchase</strong><span>(address _beneficiary, uint256 _tokenAmount) </span><span>internal </span></code><hr/><div class="description"><p>Overrides parent by storing balances instead of issuing tokens right away.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>_beneficiary</code> - Token purchaser</div><div><code>_tokenAmount</code> - Amount of tokens purchased</div></dd></dl></div></div></li><li><div class="item function"><span id="withdrawTokens" class="anchor-marker"></span><h4 class="name">withdrawTokens</h4><div class="body"><code class="signature">function <strong>withdrawTokens</strong><span>() </span><span>public </span></code><hr/><div class="description"><p>Withdraw tokens only after crowdsale ends.</p></div></div></div></li></ul></div></div></div>