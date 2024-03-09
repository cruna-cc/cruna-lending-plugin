// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SuperTransferableBadge is ERC721, Ownable {
  error NotTransferable();

  mapping(uint256 => address) private _firstOwners;

  constructor(address initialOwner) ERC721("SuperBadge", "MB") Ownable(initialOwner) {}

  function safeMint(address to, uint256 tokenId) public onlyOwner {
    _firstOwners[tokenId] = to;
    _safeMint(to, tokenId);
  }

  function firstOwnerOf(uint256 tokenId) public view returns (address) {
    return _firstOwners[tokenId];
  }
}
