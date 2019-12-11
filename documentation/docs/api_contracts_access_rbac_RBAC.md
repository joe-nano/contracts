---
id: contracts_access_rbac_RBAC
title: RBAC
---

<div class="contract-doc"><div class="contract"><h2 class="contract-header"><span class="contract-kind">contract</span> RBAC</h2><p class="description">Stores and provides setters and getters for roles and addresses. Supports unlimited numbers of roles and addresses. See //contracts/mocks/RBACMock.sol for an example of usage. This RBAC method uses strings to key roles. It may be beneficial for you to write your own implementation of this interface using Enums or similar.</p><div class="source">Source: <a href="https://github.com/2keynet/web3-alpha/blob/v0.0.3/contracts/openzeppelin-solidity/contracts/access/rbac/RBAC.sol" target="_blank">contracts/openzeppelin-solidity/contracts/access/rbac/RBAC.sol</a></div><div class="author">Author: Matt Condon (@Shrugs)</div></div><div class="index"><h2>Index</h2><ul><li><a href="contracts_access_rbac_RBAC.html#RoleAdded">RoleAdded</a></li><li><a href="contracts_access_rbac_RBAC.html#RoleRemoved">RoleRemoved</a></li><li><a href="contracts_access_rbac_RBAC.html#addRole">addRole</a></li><li><a href="contracts_access_rbac_RBAC.html#checkRole">checkRole</a></li><li><a href="contracts_access_rbac_RBAC.html#hasRole">hasRole</a></li><li><a href="contracts_access_rbac_RBAC.html#onlyRole">onlyRole</a></li><li><a href="contracts_access_rbac_RBAC.html#removeRole">removeRole</a></li></ul></div><div class="reference"><h2>Reference</h2><div class="events"><h3>Events</h3><ul><li><div class="item event"><span id="RoleAdded" class="anchor-marker"></span><h4 class="name">RoleAdded</h4><div class="body"><code class="signature">event <strong>RoleAdded</strong><span>(address operator, string role) </span></code><hr/><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>operator</code> - address</div><div><code>role</code> - string</div></dd></dl></div></div></li><li><div class="item event"><span id="RoleRemoved" class="anchor-marker"></span><h4 class="name">RoleRemoved</h4><div class="body"><code class="signature">event <strong>RoleRemoved</strong><span>(address operator, string role) </span></code><hr/><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>operator</code> - address</div><div><code>role</code> - string</div></dd></dl></div></div></li></ul></div><div class="modifiers"><h3>Modifiers</h3><ul><li><div class="item modifier"><span id="onlyRole" class="anchor-marker"></span><h4 class="name">onlyRole</h4><div class="body"><code class="signature">modifier <strong>onlyRole</strong><span>(string _role) </span></code><hr/><div class="description"><p>Modifier to scope access to a single role (uses msg.sender as addr).</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>_role</code> - the name of the role // reverts</div></dd></dl></div></div></li></ul></div><div class="functions"><h3>Functions</h3><ul><li><div class="item function"><span id="addRole" class="anchor-marker"></span><h4 class="name">addRole</h4><div class="body"><code class="signature">function <strong>addRole</strong><span>(address _operator, string _role) </span><span>internal </span></code><hr/><div class="description"><p>Add a role to an address.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>_operator</code> - address</div><div><code>_role</code> - the name of the role</div></dd></dl></div></div></li><li><div class="item function"><span id="checkRole" class="anchor-marker"></span><h4 class="name">checkRole</h4><div class="body"><code class="signature">function <strong>checkRole</strong><span>(address _operator, string _role) </span><span>public </span><span>view </span></code><hr/><div class="description"><p>Reverts if addr does not have role.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>_operator</code> - address</div><div><code>_role</code> - the name of the role // reverts</div></dd></dl></div></div></li><li><div class="item function"><span id="hasRole" class="anchor-marker"></span><h4 class="name">hasRole</h4><div class="body"><code class="signature">function <strong>hasRole</strong><span>(address _operator, string _role) </span><span>public </span><span>view </span><span>returns  (bool) </span></code><hr/><div class="description"><p>Determine if addr has role.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>_operator</code> - address</div><div><code>_role</code> - the name of the role</div></dd><dt><span class="label-return">Returns:</span></dt><dd>bool</dd></dl></div></div></li><li><div class="item function"><span id="removeRole" class="anchor-marker"></span><h4 class="name">removeRole</h4><div class="body"><code class="signature">function <strong>removeRole</strong><span>(address _operator, string _role) </span><span>internal </span></code><hr/><div class="description"><p>Remove a role from an address.</p></div><dl><dt><span class="label-parameters">Parameters:</span></dt><dd><div><code>_operator</code> - address</div><div><code>_role</code> - the name of the role</div></dd></dl></div></div></li></ul></div></div></div>