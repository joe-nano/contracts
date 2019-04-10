---
id: 2key_singleton-contracts_TwoKeyFactory
title: TwoKeyFactory
---

<div class="contract-doc"><div class="contract"><h2 class="contract-header"><span class="contract-kind">contract</span> TwoKeyFactory</h2><p class="base-contracts"><span>is</span> <a href="2key_Upgradeable.html">Upgradeable</a><span>, </span><a href="2key_MaintainingPattern.html">MaintainingPattern</a></p><div class="source">Source: <a href="https://github.com/2keynet/web3-alpha/blob/v0.0.3/contracts/2key/singleton-contracts/TwoKeyFactory.sol" target="_blank">contracts/2key/singleton-contracts/TwoKeyFactory.sol</a></div><div class="author">Author: Nikola Madjarevic</div></div><div class="index"><h2>Index</h2><ul><li><a href="2key_singleton-contracts_TwoKeyFactory.html#createProxiesForAcquisitions">createProxiesForAcquisitions</a></li><li><a href="2key_singleton-contracts_TwoKeyFactory.html#setInitialParams">setInitialParams</a></li></ul></div><div class="reference"><h2>Reference</h2><div class="functions"><h3>Functions</h3><ul><li><div class="item function"><span id="createProxiesForAcquisitions" class="anchor-marker"></span><h4 class="name">createProxiesForAcquisitions</h4><div class="body"><code class="signature">function <strong>createProxiesForAcquisitions</strong><span>(address[] addresses, uint[] valuesConversion, uint[] valuesLogicHandler, uint[] values, string _currency, string _nonSingletonHash) </span><span>public </span><span>payable </span></code><hr/><div class="description"><p>This function will handle all necessary actions which should be done on the contract in order to make them ready to work. Also, we&#x27;ve been unfortunately forced to use arrays as arguments since the stack is not deep enough to handle this amount of input information since this method handles kick-start of 3 contracts, Function used to deploy all necessary proxy contracts in order to use the campaign.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>addresses</code> - is array of addresses needed [assetContractERC20,moderator]</div><div><code>valuesConversion</code> - is array containing necessary values to start conversion handler contract</div><div><code>valuesLogicHandler</code> - is array of values necessary to start logic handler contract</div><div><code>values</code> - is array containing values necessary to start campaign contract</div><div><code>_currency</code> - is the main currency token price is set</div><div><code>_nonSingletonHash</code> - is the hash of non-singleton contracts active with responding 2key-protocol version at the moment</div></dd></dl></div></div></li><li><div class="item function"><span id="setInitialParams" class="anchor-marker"></span><h4 class="name">setInitialParams</h4><div class="body"><code class="signature">function <strong>setInitialParams</strong><span>(address _twoKeySingletonRegistry, address _twoKeyAdmin, address[] _maintainers) </span><span>public </span></code><hr/><div class="description"><p>Function to set initial parameters for the contract.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>_twoKeySingletonRegistry</code> - is the address of singleton registry contract</div><div><code>_twoKeyAdmin</code> - is the address if twoKeyAdmin contract</div><div><code>_maintainers</code> - is the array of maintainers</div></dd></dl></div></div></li></ul></div></div></div>