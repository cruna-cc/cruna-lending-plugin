// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

// Author: Francesco Sullo <francesco@sullo.co>

import {BadgeCollectorPluginBase} from "./BadgeCollectorPluginBase.sol";

contract BadgeCollectorUpgradeablePlugin is BadgeCollectorPluginBase {
  function _nameId() internal view virtual override returns (bytes4) {
    return bytes4(keccak256("BadgeCollectorUpgradeablePlugin"));
  }

  // @dev This empty reserved space is put in place to allow future versions to add new
  // variables without shifting down storage in the inheritance chain.
  // See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps

  uint256[50] private __gap;
}
