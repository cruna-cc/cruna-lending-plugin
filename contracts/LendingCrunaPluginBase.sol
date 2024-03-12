// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {CrunaPluginBase} from "@cruna/protocol/plugins/CrunaPluginBase.sol";

abstract contract LendingCrunaPluginBase is CrunaPluginBase, IERC721Receiver {
  event AssetWithdrawn(address indexed assetAddress, uint256 indexed tokenId, address withdrawer);

  error InvalidValidity();

  function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
    return (interfaceId == type(IERC721Receiver).interfaceId || interfaceId == type(IERC165).interfaceId);
  }

  function onERC721Received(
    address /* operator */,
    address /* from */,
    uint256 /* tokenId */,
    bytes memory /* data */
  ) external virtual override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function _isProtected() internal view virtual override returns (bool) {
    return _conf.manager.hasProtectors();
  }

  function _isProtector(address protector) internal view virtual override returns (bool) {
    return _conf.manager.isProtector(protector);
  }

  function requiresToManageTransfer() external pure override returns (bool) {
    return false;
  }

  function reset() external override {
    // do nothing because it does not need any reset
  }

  function requiresResetOnTransfer() external pure returns (bool) {
    return false;
  }

  function _reset() internal {
    // nothing to reset
  }

  // @dev This empty reserved space is put in place to allow future versions to add new
  // variables without shifting down storage in the inheritance chain.
  // See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps

  uint256[50] private __gap;
}
