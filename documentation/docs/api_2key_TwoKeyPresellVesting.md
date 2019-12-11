---
id: 2key_TwoKeyPresellVesting
title: TwoKeyPresellVesting
---

<div class="contract-doc"><div class="contract"><h2 class="contract-header"><span class="contract-kind">contract</span> TwoKeyPresellVesting</h2><p class="base-contracts"><span>is</span> <a href="openzeppelin-solidity_contracts_token_ERC20_TokenVesting.html">TokenVesting</a></p><div class="source">Source: <a href="git+https://github.com/2keynet/web3-alpha/blob/v0.0.3/contracts/2key/TwoKeyPresellVesting.sol" target="_blank">2key/TwoKeyPresellVesting.sol</a></div></div><div class="index"><h2>Index</h2><ul><li><a href="2key_TwoKeyPresellVesting.html#">fallback</a></li><li><a href="2key_TwoKeyPresellVesting.html#vestedAmount">vestedAmount</a></li></ul></div><div class="reference"><h2>Reference</h2><div class="functions"><h3>Functions</h3><ul><li><div class="item function"><span id="fallback" class="anchor-marker"></span><h4 class="name">fallback</h4><div class="body"><code class="signature">function <strong></strong><span>(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration, bool _revocable, uint256 _numPayments, bool _withBonus, uint256 _bonusPrecentage) </span><span>public </span></code><hr/><dl><dt><span class="label-modifiers">Modifiers:</span></dt><dd></dd><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>_beneficiary</code> - address</div><div><code>_start</code> - uint256</div><div><code>_cliff</code> - uint256</div><div><code>_duration</code> - uint256</div><div><code>_revocable</code> - bool</div><div><code>_numPayments</code> - uint256</div><div><code>_withBonus</code> - bool</div><div><code>_bonusPrecentage</code> - uint256</div></dd></dl></div></div></li><li><div class="item function"><span id="vestedAmount" class="anchor-marker"></span><h4 class="name">vestedAmount</h4><div class="body"><code class="signature">function <strong>vestedAmount</strong><span>(ERC20Basic token) </span><span>public </span><span>view </span><span>returns  (uint256) </span></code><hr/><div class="description"><p>Calculates the amount that has already vested.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>token</code> - ERC20 token which is being vested</div></dd><dt><span class="label-return">Returns:</span></dt><dd>uint256</dd></dl></div></div></li></ul></div></div></div>