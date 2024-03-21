// SPDX-License-Identifier: GPL3
pragma solidity ^0.8.20;

interface IERC7531 {
  /**
   * @notice MUST be emitted when the token's technical owner (the contract holding the token) is different
   *      from its actual owner (the entity with rights over the token).
   * @dev This scenario is common in staking, where a staking contract is the technical owner. The event MUST
   *      be emitted in the same or any subsequent block as the Transfer event for the token.
   *      A later Transfer event involving the same token supersedes this RightsHolderChange event.
   *      To ensure authenticity, entities listening to this event MUST verify that the contract emitting
   *      the event matches the token's current owner as per the related Transfer event.
   *
   * @param tokenAddress The address of the token contract.
   * @param tokenId The ID of the token.
   * @param holder The address of the actual rights holder of the token.
   * @param rights The type of rights held by the holder. The supported rights in V1 are:
   *
   *           0x399d2b36   // bytes4(keccak256("ownership"))
   *           0x230a5961   // bytes4(keccak256("usage"))
   *
   *        This approach using bytes4 allows the community to add more rights in future versions without
   *        breaking compatibility with this interface.
   */
  event RightsHolderChange(address indexed tokenAddress, uint256 indexed tokenId, address indexed holder, bytes4 rights);

  /**
   * @dev Returns the address of the entity with rights over the token, distinct from the current owner.
   *      The function MUST revert if the token does not exist or is not currently held.
   *
   * @param tokenAddress The address of the ERC-721 contract.
   * @param tokenId The ID of the token.
   * @param rights The type of rights held by the holder.
   * @return The address of the entity with rights over the token.
   */
  function rightsHolderOf(address tokenAddress, uint256 tokenId, bytes4 rights) external view returns (address);
}
