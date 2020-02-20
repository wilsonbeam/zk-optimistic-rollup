include "./utils.circom";
include "./note_proof.circom";
include "./inclusion_proof.circom";
include "./nullifier_proof.circom";
include "../../node_modules/circomlib/circuits/eddsaposeidon.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";

template ZkTransfer(tree_depth, in, out) {
    /** Private Signals */
    signal private input notes[in];
    signal private input amount[in];
    signal private input pub_keys[2][in];
    signal private input salts[in];
    signal private input nfts[in];
    signal private input signatures[3][in];
    signal private input path[in];
    signal private input siblings[tree_depth][in];
    signal private input utxo_amount[out];
    signal private input utxo_pub_keys[2][out];
    signal private input utxo_nfts[out];
    signal private input utxo_salts[out];
    /** Public Signals */
    signal input fee;
    signal input inclusion_references[in];
    signal input nullifiers[in];
    signal input utxos[out];

    /** Constraints */
    // 1. Note proof
    // 2. Ownership proof
    // 3. Inclusion proof of all input UTXOs
    // 4. Nullifying proof of all input UTXOs
    // 5. Generate new utxos
    // 6. Check zero sum proof

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
        spending[i].nft <== nfts[i];
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

    component new_utxos[out];
    for (var i = 0; i < out; i++) {
        // 5. Generate new utxos
        new_utxos[i] = NoteProof();
        new_utxos[i].note <== utxos[i];
        new_utxos[i].pub_key[0] <== utxo_pub_keys[0][i];
        new_utxos[i].pub_key[1] <== utxo_pub_keys[1][i];
        new_utxos[i].nft <== utxo_nfts[i];
        new_utxos[i].salt <== utxo_salts[i];
        new_utxos[i].amount <== utxo_amount[i];
    }
    // 6. Check nft transfers
    var BASE8 = [
        5299619240641551281634865583518297030282874472190772894086521144482721001553,
        16950150798460657717958625567821834550301663161624707787222815936182638968203
    ];
    component prev_nft_mult[in + 1];
    component prev_nft_to_bits[in];
    component next_nft_mult[out + 1];
    component next_nft_to_bits[out];
    var prev_nft_sum;
    var next_nft_sum;
    var inflow;
    var outflow;


    // 7. Check zero sum & nfts' non-fungibility
    prev_nft_mult[0] = EscalarMulAny(2);
    prev_nft_mult[0].e[0] <== 1;
    prev_nft_mult[0].e[1] <== 0;
    prev_nft_mult[0].p[0] <== BASE8[0];
    prev_nft_mult[0].p[1] <== BASE8[1];
    next_nft_mult[0] = EscalarMulAny(2);
    next_nft_mult[0].e[0] <== 1;
    next_nft_mult[0].e[1] <== 0;
    next_nft_mult[0].p[0] <== BASE8[0];
    next_nft_mult[0].p[1] <== BASE8[1];
    for ( var i = 0; i < in; i++) {
        inflow += amount[i];
        prev_nft_sum += nfts[i];
        prev_nft_to_bits[i] = NFTtoBits(253);
        prev_nft_to_bits[i].nft <== nfts[i];
        prev_nft_mult[i + 1] = EscalarMulAny(253);
        for(var j = 0; j < 253; j++) {
            prev_nft_mult[i + 1].e[j] <== prev_nft_to_bits[i].out[j]
        }
        prev_nft_mult[i + 1].p[0] <== prev_nft_mult[i].out[0]
        prev_nft_mult[i + 1].p[1] <== prev_nft_mult[i].out[1]
    }
    for ( var i = 0; i < out; i++) {
        outflow += utxo_amount[i];
        next_nft_sum += utxo_nfts[i];
        next_nft_to_bits[i] = NFTtoBits(253);
        next_nft_to_bits[i].nft <== utxo_nfts[i];
        next_nft_mult[i + 1] = EscalarMulAny(253);
        for(var j = 0; j < 253; j++) {
            next_nft_mult[i + 1].e[j] <== next_nft_to_bits[i].out[j]
        }
        next_nft_mult[i + 1].p[0] <== next_nft_mult[i].out[0]
        next_nft_mult[i + 1].p[1] <== next_nft_mult[i].out[1]
    }
    outflow += fee;

    component no_money_printed = ForceEqualIfEnabled();
    no_money_printed.enabled <== 1;
    no_money_printed.in[0] <== inflow;
    no_money_printed.in[1] <== outflow;

    component nfts_are_non_fungible[3];
    nfts_are_non_fungible[0] = ForceEqualIfEnabled();
    nfts_are_non_fungible[1] = ForceEqualIfEnabled();
    nfts_are_non_fungible[2] = ForceEqualIfEnabled();
    /// Multiplication of all nfts in the used notes should equal
    /// to the mult of the all nfts in the new uxtos.
    /// If nft is zero, mult 1.
    nfts_are_non_fungible[0].enabled <== 1;
    nfts_are_non_fungible[0].in[0] <== prev_nft_mult[in].out[0];
    nfts_are_non_fungible[0].in[1] <== prev_nft_mult[in].out[1];
    nfts_are_non_fungible[1].enabled <== 1;
    nfts_are_non_fungible[1].in[0] <== next_nft_mult[out].out[0];
    nfts_are_non_fungible[1].in[1] <== next_nft_mult[out].out[1];
    /// Sum of all nfts in the used notes should equal
    /// to the sum of the all nfts in the new uxtos.
    nfts_are_non_fungible[2].enabled <== 1;
    nfts_are_non_fungible[2].in[0] <== prev_nft_sum;
    nfts_are_non_fungible[2].in[1] <== next_nft_sum;
}
