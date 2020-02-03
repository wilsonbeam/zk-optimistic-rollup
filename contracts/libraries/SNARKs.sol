pragma solidity >= 0.6.0;

import { Pairing } from "./Pairing.sol";


library SNARKsVerifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] ic;
    }
    struct Proof {
        Pairing.G1Point a;
        Pairing.G2Point b;
        Pairing.G1Point c;
    }
    function zkSNARKs(VerifyingKey memory vk, uint[] memory input, Proof memory proof) internal view returns (bool) {
        uint256 SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        require(input.length + 1 == vk.ic.length,"verifier-bad-input");
        // Compute the linear combination vkX
        Pairing.G1Point memory vkX = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < SNARK_SCALAR_FIELD,"verifier-gte-snark-scalar-field");
            vkX = Pairing.addition(vkX, Pairing.scalar_mul(vk.ic[i + 1], input[i]));
        }
        vkX = Pairing.addition(vkX, vk.ic[0]);
        if (
            !Pairing.pairingProd4(
                Pairing.negate(proof.a), proof.b,
                vk.alfa1, vk.beta2,
                vkX, vk.gamma2,
                proof.c, vk.delta2
            )
        ) {
            return true;
        }
        return false;
    }

    function proof(uint[8] memory proofArr) internal pure returns (Proof memory) {
        return Proof(
            Pairing.G1Point(proofArr[0], proofArr[1]),
            Pairing.G2Point(
                [
                    proofArr[2], proofArr[3]
                ],
                [
                    proofArr[4], proofArr[5]
                ]
            ),
            Pairing.G1Point(proofArr[6], proofArr[7])
        );
    }
}
