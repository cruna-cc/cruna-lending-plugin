// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

//import "hardhat/console.sol";

contract CoolBadge is ERC721, Ownable {
  error NotTransferable();

  constructor(address initialOwner) ERC721("CoolBadge", "MB") Ownable(initialOwner) {}

  function safeMint(address to, uint256 tokenId) public onlyOwner {
    _safeMint(to, tokenId);
  }

  function _update(address to, uint256 tokenId, address auth) internal virtual override(ERC721) returns (address) {
    if (_ownerOf(tokenId) != address(0)) {
      revert NotTransferable();
    }
    return super._update(to, tokenId, auth);
  }
}
