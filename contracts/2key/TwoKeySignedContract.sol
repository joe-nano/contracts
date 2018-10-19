pragma solidity ^0.4.24;
import './TwoKeyContract.sol';

contract TwoKeySignedContract is TwoKeyContract {
  // the 2key link generated by the owner of this contract contains a secret which is a private key,
  // this is the public part of this secret
  mapping(address => address)  public public_link_key;

  function setPublicLinkKey(address _public_link_key) public {
    address owner_influencer = msg.sender;
    require(balanceOf(owner_influencer) > 0,'no ARCs');
    require(public_link_key[owner_influencer] == address(0),'public link key already defined');
    public_link_key[owner_influencer] = _public_link_key;
  }

  function transferSig(bytes sig) public returns (address) {
    // move ARCs based on signature information

    // if version=1, with_cut is true then sig also include the cut (percentage) each influencer takes from the bounty
    // the cut is stored in influencer2cut
    uint idx = 0;
//    uint8 version;
//    if (idx+1 <= sig.length) {
//      idx += 1;
//      assembly
//      {
//        version := mload(add(sig, idx))
//      }
//    }
//    require(version < 2);
//    bool with_cut = false;
//    if (version == 1) {
//      with_cut = true;
//    }

    address old_address;
    if (idx+20 <= sig.length) {
      idx += 20;
      assembly
      {
        old_address := mload(add(sig, idx))
      }
    }

    address old_public_link_key = public_link_key[old_address];
    require(old_public_link_key != address(0),'no public link key');

    while (idx + 65 <= sig.length) {
      // The signature format is a compact form of:
      //   {bytes32 r}{bytes32 s}{uint8 v}
      // Compact means, uint8 is not padded to 32 bytes.
      idx += 32;
      bytes32 r;
      assembly
      {
        r := mload(add(sig, idx))
      }

      idx += 32;
      bytes32 s;
      assembly
      {
        s := mload(add(sig, idx))
      }

      idx += 1;
      uint8 v;
      assembly
      {
        v := mload(add(sig, idx))
      }

      // idx was increased by 65

      bytes32 hash;
      address new_public_key;
      address new_address;
//      if (idx + (with_cut ? 41 : 40) < sig.length) {
      if (idx + 41 <= sig.length) {  // its  a < and not a <= because we dont want this to be the final iteration for the converter
        uint8 bounty_cut;
//        if (with_cut)
        {
          idx += 1;
          assembly
          {
            bounty_cut := mload(add(sig, idx))
          }
          require(bounty_cut > 0,'bounty/weight not defined (1..255)');  // 255 are used to indicate default (equal part) behaviour
        }

        idx += 20;
        assembly
        {
          new_address := mload(add(sig, idx))
        }

        idx += 20;
        assembly
        {
          new_public_key := mload(add(sig, idx))
        }

//        if (with_cut)
//        {
//          require(bounty_cut > 0);

        // update (only once) the cut used by each influencer
        // we will need this in case one of the influencers will want to start his own off-chain link
        if (influencer2cut[new_address] == 0) {
          influencer2cut[new_address] = uint256(bounty_cut);
        } else {
          require(influencer2cut[new_address] == uint256(bounty_cut),'bounty cut can not be modified');
        }

        // update (only once) the public address used by each influencer
        // we will need this in case one of the influencers will want to start his own off-chain link
        if (public_link_key[new_address] == 0) {
          public_link_key[new_address] = new_public_key;
        } else {
          require(public_link_key[new_address] == new_public_key,'public key can not be modified');
        }

        hash = keccak256(abi.encodePacked(bounty_cut, new_public_key, new_address));
//        }

        // check if we exactly reached the end of the signature. this can only happen if the signature
        // was generated with free_join_take and in this case the last part of the signature must have been
        // generated by the caller of this method
        if (idx == sig.length) {
          require(new_address == msg.sender || owner == msg.sender,'only the contractor or the last in the link can call transferSig');
        }
      } else {
        // handle short signatures generated with free_take
        // signed message for the last step is the address of the converter
        new_address = msg.sender;
        hash = keccak256(abi.encodePacked(new_address));
      }
      // assume users can take ARCs only once... this could be changed
      if (received_from[new_address] == 0) {
        transferFrom(old_address, new_address, 1);
      } else {
        require(received_from[new_address] == old_address,'only tree ARCs allowed');
      }

      // check if we received a valid signature
      address signer = ecrecover(hash, v, r, s);
      require (signer == old_public_link_key, 'illegal signature');
      old_public_link_key = new_public_key;
      old_address = new_address;
    }
    require(idx == sig.length,'illegal message size');

    return old_address;
  }

  function buySign(bytes sig) public payable {
    // validate sig AND populate received_from and influencer2cut
    transferSig(sig);

    buyProduct();
  }
}

contract TwoKeySignedAcquisitionContract is TwoKeyAcquisitionContract, TwoKeySignedContract {
  constructor(TwoKeyEventSource _eventSource, string _name, string _symbol,
        uint256 _tSupply, uint256 _quota, uint256 _cost, uint256 _bounty,
        uint256 _units, string _ipfs_hash)
        public
        TwoKeyAcquisitionContract(_eventSource,_name,_symbol,_tSupply,_quota,_cost,_bounty,_units,_ipfs_hash)
  {
  }
}

contract TwoKeySignedPresellContract is TwoKeyPresellContract, TwoKeySignedContract {
  constructor(TwoKeyEventSource _eventSource, string _name, string _symbol,
        uint256 _tSupply, uint256 _quota, uint256 _cost, uint256 _bounty,
        string _ipfs_hash, ERC20full _erc20_token_sell_contract)
        public
        TwoKeyPresellContract(_eventSource,_name,_symbol,_tSupply,_quota,_cost,_bounty,_ipfs_hash,_erc20_token_sell_contract)
  {
  }
}
