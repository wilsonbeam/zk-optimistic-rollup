include "./note_proof.circom";
include "./ownership_proof.circom";
include "./inclusion_proof.circom";
include "./nullifier_proof.circom";
include "../../node_modules/circomlib/circuits/eddsaposeidon.circom";

template ZkWithdraw(tree_depth, in) {
    /** Private Signals */
    signal private input notes[in];
    signal private input amount[in];
    signal private input pub_keys[2][in];
    signal private input salts[in];
    signal private input signatures[3][in];
    signal private input path[in];
    signal private input siblings[tree_depth][in];
    /** Public Signals */
    signal input withdrawal_amount;
    signal input fee;
    signal input to;
    signal input inclusion_references[in];
    signal input nullifiers[in];

    /** Constraints */
    // 1. Note proof
    // 2. Ownership proof
    // 3. Inclusion proof of all input UTXOs
    // 4. Nullifying proof of all input UTXOs
    // 5. Check zero sum proof

    component spending[in];
    component ownership_proof[in];
    component nullifier_proof[in];
    component inclusion_proof[in];
    for(var i = 0; i < in; i ++) {
        // 1. Note proof
        spending[i] = NoteProof();
        spending[i].note <== notes[i];
        spending[i].pub_key[0] <== pub_keys[0][i];
        spending[i].pub_key[1] <== pub_keys[1][i];
        spending[i].salt <== salts[i];
        spending[i].amount <== amount[i];

        // 2. The signature should match with the pub key of the note
        ownership_proof[i] = EdDSAPoseidonVerifier();
        ownership_proof[i].enabled <== 1;
        ownership_proof[i].R8x <== spending[i].pub_key[0];
        ownership_proof[i].R8y <== spending[i].pub_key[1];
        ownership_proof[i].M <== spending[i].note;
        ownership_proof[i].Ax <== signatures[0][i];
        ownership_proof[i].Ay <== signatures[1][i];
        ownership_proof[i].S <== signatures[2][i];

        // 2. Nullifier proof
        nullifier_proof[i] = NullifierProof();
        nullifier_proof[i].nullifier <== nullifiers[i];
        nullifier_proof[i].note <== notes[i];
        nullifier_proof[i].salt <== salts[i];

        // 4. Inclusion proof
        inclusion_proof[i] = InclusionProof(tree_depth);
        inclusion_proof[i].root <== inclusion_references[i];
        inclusion_proof[i].leaf <== notes[i];
        inclusion_proof[i].path <== path[i];
        for(var j = 0; j < tree_depth; j++) {
            inclusion_proof[i].siblings[j] <== siblings[j][i];
        }
    }

    // 5. Check zero sum
    var inflow;
    for ( var i = 0; i < in; i++) {
        inflow += amount[i]
    }
    var outflow;
    outflow += withdrawal_amount;
    outflow += fee;
    inflow === outflow;
}
