// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Minimalistic guardian to trust plugins implementations
contract Guardian is Ownable {
  mapping(address => bool) private _trusted;

  event Trusted(address indexed implementation);

  constructor(address admin) Ownable(admin) {}

  function trust(address implementation) external onlyOwner {
    _trusted[implementation] = true;
    emit Trusted(implementation);
  }

  function trusted(address implementation) external view returns (bool) {
    return _trusted[implementation];
  }

  uint256[50] private __gap;
}
