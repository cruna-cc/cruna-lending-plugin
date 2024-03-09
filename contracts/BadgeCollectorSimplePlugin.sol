// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

// Author: Francesco Sullo <francesco@sullo.co>

import {BadgeCollectorPluginBase} from "./BadgeCollectorPluginBase.sol";

contract BadgeCollectorSimplePlugin is BadgeCollectorPluginBase {
  error NotUpgradeable();

  function _nameId() internal view virtual override returns (bytes4) {
    return bytes4(keccak256("BadgeCollectorSimplePlugin"));
  }

  function upgrade(address) external pure override {
    revert NotUpgradeable();
  }
}
