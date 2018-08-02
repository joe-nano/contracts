pragma solidity ^0.4.24;
import './TwoKeyContract.sol';

contract TwoKeySignedContract is TwoKeyContract {
  // the 2key link generated by the owner of this contract contains a secret which is a private key,
  // this is the public part of this secret
  mapping(address => address)  public public_link_key;

  function setPublicLinkKey(address _public_link_key) public {
    address owner_influencer = msg.sender;
    require(balanceOf(owner_influencer) > 0);
    require(public_link_key[owner_influencer] == address(0));
    public_link_key[owner_influencer] = _public_link_key;
  }

  function transferSig(bytes sig) public {
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
    require(old_public_link_key != address(0));

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

      bytes32 hash;
      address new_public_key;
      address new_address;
//      if (idx + (with_cut ? 41 : 40) < sig.length) {
      if (idx + 41 < sig.length) {  // its  a < and not a <= because we dont want this to be the final iteration for the converter
        uint8 bounty_cut;
//        if (with_cut)
        {
          idx += 1;
          assembly
          {
            bounty_cut := mload(add(sig, idx))
          }
          require(bounty_cut > 0);  // 0 and 255 are used to indicate default (equal part) behaviour
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
        {
//          require(bounty_cut > 0);
          if (influencer2cut[new_address] == 0) {
            influencer2cut[new_address] = uint256(bounty_cut);
          } else {
            require(influencer2cut[new_address] == uint256(bounty_cut));
          }
          hash = keccak256(abi.encodePacked(bounty_cut, new_public_key, new_address));
        }
//        else {
//          hash = keccak256(abi.encodePacked(new_public_key, new_address));
//        }
      } else {
        require(idx == sig.length);
        // signed message for the last step is the address of the converter
        new_address = msg.sender;
        hash = keccak256(abi.encodePacked(new_address));
      }
      // assume users can take ARCs only once... this could be changed
      if (received_from[new_address] == 0) {
        transferFrom(old_address, new_address, 1);
      } else {
        require(received_from[new_address] == old_address);
      }

      // check if we received a valid signature
      address signer = ecrecover(hash, v, r, s);
      if (signer != old_public_link_key) {
        revert();
      }
      old_public_link_key = new_public_key;
      old_address = new_address;
    }
//    require(idx == sig.length);
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