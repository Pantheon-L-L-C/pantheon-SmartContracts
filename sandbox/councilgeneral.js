const { ethers, utils } = require("ethers");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

const users = [
    { address: "0xD08c8e6d78a1f64B1796d6DC3137B19665cb6F1F", amount: 1 },
    { address: "0xb7D15753D3F76e7C892B63db6b4729f700C01298", amount: 0 },
    { address: "0xf69Ca530Cd4849e3d1329FBEC06787a96a3f9A68", amount: 1 },
    { address: "0xa8532aAa27E9f7c3a96d754674c99F1E2f824900", amount: 1 },
    { address: "0xa8532aAa27E9f7c3a96d754674c99F1E2f824100", amount: 0 },
    { address: "0xa8532aAa27E9f7c3a96d754674c99F1E2f824200", amount: 1 },
    { address: "0xa8532aAa27E9f7c3a96d754674c99F1E2f824300", amount: 1 },
    { address: "0xa8532aAa27E9f7c3a96d754674c99F1E2f824500", amount: 0 },
    { address: "0xa8532aAa27E9f7c3a96d754674c99F1E2f824600", amount: 1 },
    { address: "0xa8532aAa27E9f7c3a96d754674c99F1E2f824700", amount: 1 }
  ];

const elements = users.map((x) =>
    utils.solidityKeccak256(["address", "uint256"], [x.address, x.amount])
  );

const merkleTree = new MerkleTree(elements, keccak256, { sort: true });

const root = merkleTree.getHexRoot();

const leaf = elements[1];
const proof = merkleTree.getHexProof(leaf);
console.log(merkleTree.verify(proof, leaf, root)) // true
console.log(proof)
console.log(root)
