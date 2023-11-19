// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

interface IMaker {
    /// @notice handles minting xTokens for the user
    /// @dev it is assumed that the token in will always be either Weth or USDC.
    /// this is enfored inside of the Maru contract when loans are initiated.
    /// @param _sender the user who is minting the xToken
    /// @param _tokenIn the token that is being sent from the Maru Contract
    /// @param _amount the amount of _tokenIn that is being sent
    /// @return xTokenOut the amount of xTokens the user minted
    /// @return extraBaseTokenOut the amount of extra base tokens the user got 'refunded'
    function mint(address _sender, address _tokenIn, uint256 _amount)
        external
        returns (uint256 xTokenOut, uint256 extraBaseTokenOut);

    /// @notice redeem xTokens and repay the loan that they original issued from.
    /// @param _sender the user who is redeeming and whos loan is being paid back
    /// @param _amount the amount of xTokens to redeem
    function redeem(address _sender, uint256 _amount) external;
}
