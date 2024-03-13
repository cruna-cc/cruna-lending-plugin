// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LendingCrunaPlugin} from "../LendingCrunaPlugin.sol";

contract LendingCrunaPluginMock is LendingCrunaPlugin {
  address public immutable TRT_WALLET = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

  function _nameId() internal view virtual override returns (bytes4) {
    return bytes4(keccak256("LendingCrunaPluginMock"));
  }
}
