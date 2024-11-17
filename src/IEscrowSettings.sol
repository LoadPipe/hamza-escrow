
//TODO: comment
interface IEscrowSettings {
    function vaultAddress() external view returns (address);
    function feeBps() external view returns (uint256);
}