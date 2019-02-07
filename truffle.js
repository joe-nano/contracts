// Allows us to use ES6 in our migrations and tests.
require('babel-register');
// https://github.com/trufflesuite/truffle-hdwallet-provider
const HDWalletProvider = require('truffle-hdwallet-provider');
const PrivateKeyProvider = require('truffle-privatekey-provider');
// const HDWalletProvider = require('./WalletProvider');
const LedgerProvider = require('./LedgerProvider');

const mnemonic = 'laundry version question endless august scatter desert crew memory toy attract cruel';
//const mnemonic_private = 'north depend loyal purpose because theme funny script debris divert kitchen junk diary angry method';
// make sure you have Ether on rinkeby address 0xb3fa520368f2df7bed4df5185101f303f6c7decc
const infuraApiKey = 'db719ec4fd734e798e74782bce13bbca';

const ledgerOptions = {
  networkId: 3, // ropsten testnet
  accountsOffset: 0 // we use the first address
};

/*

#### STAGING PLASMA

**RPC**:  https://rpc.private.test.k8s.2key.net:443

**WS**:   wss://ws.private.test.k8s.2key.net:443


#### RINKEBY

**RPC**:  https://rpc.public.test.k8s.2key.net:443

**WS**:   wss://ws.public.test.k8s.2key.net:443


#### PROD-PLASMA

**RPC**:  https://rpc.private.prod.k8s.2key.net:443

**WS**:   wss://ws.private.prod.k8s.2key.net:443


#### MAIN-NET

**RPC**:  https://rpc.public.prod.k8s.2key.net:443

**WS**:   wss://ws.public.prod.k8s.2key.net:443

*/


module.exports = {
  networks: {
    'dev-local': {
      provider: new HDWalletProvider(mnemonic, 'http://localhost:8545'),
      network_id: 8086, // Match any network id
      gas: 8000000,
      gasPrice: 2000000000
    },

    'development' : {
        host: "localhost",
        port: 8545,
        network_id: "*", // Match any network id
        gas: 10000000,
        gasPrice: 2000000000
    },

    'rinkeby' : {
      provider: () => LedgerProvider(`https://rinkeby.infura.io/v3/${infuraApiKey}`, {
        networkId: 4,
        // https://github.com/LedgerHQ/ledgerjs/issues/200
        path: "44'/60'/0'/0",
        askConfirm: true,
        accountsLength: 1,
        accountsOffset: 0,
      }),
      network_id: 4,
      gas: 7000000,
      gasPrice: 50000000000,
    },

    'public.test.k8s' : {
      provider: () => LedgerProvider('https://rpc.public.test.k8s.2key.net', {
        networkId: 3,
        // https://github.com/LedgerHQ/ledgerjs/issues/200
        path: "44'/60'/0'/0",
        // askConfirm: true,
        askConfirm: false,
        accountsLength: 1,
        accountsOffset: 0,
      }),
      network_id: 3,
      gas: 8000000,
      gasPrice: 50000000000,
    },

    'private.test.k8s': {
      provider: () => LedgerProvider('https://rpc.private.test.k8s.2key.net', {
        networkId: 98052,
        // https://github.com/LedgerHQ/ledgerjs/issues/200
        path: "44'/60'/0'/0",
        // askConfirm: true,
        askConfirm: false,
        accountsLength: 1,
        accountsOffset: 0,
      }),
      network_id: 98052,
      gas: 7000000,
      gasPrice: 0,
      // host: 'https://ext.geth.private.test.k8s.2key.net',
      // port: 8545,
      // network_id: 98052, // Match any network id
      //network_id: 98052,
      //gas: 7000000,
      //gasPrice: 0,
      // gasPrice: 100000000000,
      // gasPrice: 2000000000
    },

    'public.test.k8s-hdwallet' : {
      provider: () => new HDWalletProvider(mnemonic, 'https://rpc.public.test.k8s.2key.net'),
      network_id: 3,
      gas: 8000000,
      gasPrice: 50000000000,
    },

    'private.test.k8s-hdwallet': {
      // 0x0E0D3E393B47058c3A85e33EFE542B7fBc51BB07oru
      // http://ext.geth.private.test.k8s.2key.net:8545/
      // provider: () => new PrivateKeyProvider('da16b3f97e1f39ac93788d925e17286f20dc737cc208d57ca4d49b128b69eb85', 'http://ext.geth.private.test.k8s.2key.net:8545'),
      provider: () => new HDWalletProvider(mnemonic, 'https://rpc.private.test.k8s.2key.net'),
      // host: 'https://ext.geth.private.test.k8s.2key.net',
      // port: 8545,
      // network_id: 98052, // Match any network id
      network_id: 98052,
      gas: 7000000,
      gasPrice: 0,
      // gasPrice: 100000000000,
      // gasPrice: 2000000000
    },


    'rinkeby-test' : {
        provider: () => new HDWalletProvider(mnemonic, 'https://rinkeby.infura.io/v3/904c762bd6984606bf8ae7f30d7cb28c'),
        network_id: 4,
        gas: 7000000,
        gasPrice: 50000000000
    },


    'ropsten' : {
        provider: () => new HDWalletProvider(mnemonic, `https://ropsten.infura.io/v3/904c762bd6984606bf8ae7f30d7cb28c`),
        network_id: 3,
        gas: 8000000,
        gasPrice: 2500000000000
    },

    'ropsten.staging' : {
      provider: () => LedgerProvider(`https://ropsten.infura.io/v3/${infuraApiKey}`, {
        networkId: 3,
        // https://github.com/LedgerHQ/ledgerjs/issues/200
        path: "44'/60'/0'/0",
        askConfirm: false,
        accountsLength: 1,
        accountsOffset: 0,
      }),
      // provider: () => new HDWalletProvider(mnemonic, 'https://ropsten.infura.io/v3/71d39c30bc984e8a8a0d8adca84620ad'),
      network_id: 3,
      gas: 8000000,
      gasPrice: 50000000000
    },


    'staging-2key': {
      provider: () => LedgerProvider('http://18.233.2.70:8500/ropsten', {
        networkId: 3,
        // https://github.com/LedgerHQ/ledgerjs/issues/200
        path: "44'/60'/0'/0",
        askConfirm: true,
        accountsLength: 1,
        accountsOffset: 0,
      }),
      // provider: () => new HDWalletProvider(mnemonic, 'https://ropsten.infura.io/v3/71d39c30bc984e8a8a0d8adca84620ad'),
      network_id: 3,
      gas: 8000000,
      gasPrice: 50000000000
    },

    'kovan': {
      provider: () => new HDWalletProvider(mnemonic, 'https://kovan.infura.io/6rAARDbMXpJlwODa2kbk'),
      network_id: 42,
      gas: 7000000,
      gasPrice: 3000000000
    },
    'plasma-local': {
      provider: () => new HDWalletProvider(mnemonic, 'http://localhost:18545'),
      network_id: 8087,
      gas: 7000000,
      gasPrice: 0
    },

    'plasma-dev': {
      provider: () => new HDWalletProvider(mnemonic, 'http://astring.aydnep.com.ua:38545'),
      network_id: 8087,
      gas: 7000000,
      gasPrice: 0
    },
  }
};
