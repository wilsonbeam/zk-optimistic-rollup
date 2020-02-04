pragma solidity >= 0.6.0;

interface IRollUpable {
    /**
     * @dev Start to generate a proof for the UTXO tree transition
     */
    function newProofOfUTXORollUp(uint startingRoot, uint startingIndex, uint[] calldata initialSiblings) external;

    /**
     * @dev Start to generate a proof for the nullifier tree transition
     */
    function newProofOfNullifierRollUp(bytes32 prevRoot) external;

    /**
     * @dev Start to generate a proof for the withdrawal tree transition
     */
    function newProofOfWithdrawalRollUp(uint startingRoot, uint startingIndex) external;

    /**
     * @dev Append items to the utxo tree and record the intermediate result on the storage.
     *      This MiMC roll up costs around 1.4 million per appending.
     */
    function updateProofOfUTXORollUp(uint id, uint[] calldata leaves) external;

    /**
     * @dev Append items to the nullifier tree and record the intermediate result on the storage.
     */
    function updateProofOfNullifierRollUp(uint id, bytes32[] calldata leaves, bytes32[256][] calldata siblings) external;

    /**
     * @dev Append items to the withdrawal tree and record the intermediate result on the storage
     */
    function updateProofOfWithdrawalRollUp(uint id, uint[] calldata initialSiblings, uint[] calldata leaves) external;
}