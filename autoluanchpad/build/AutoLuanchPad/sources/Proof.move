module ItsRare::Proof {
    use std::vector;
    use aptos_std::aptos_hash::keccak256;
    use aptos_std::comparator::{is_smaller_than, compare_u8_vector};

    fun compute_pair_hash(a: vector<u8>, b: vector<u8>): vector<u8> {
        if(is_smaller_than(&compare_u8_vector(a, b))){
            vector::append(&mut a, b);
            keccak256(a)
        }else{
            vector::append(&mut b, a);
            keccak256(b)
        }
    }

    public fun get_root_hash(proof: vector<vector<u8>>, leaf: vector<u8>): vector<u8> {
        let computedHash = leaf;
        let num = vector::length(&proof);
        let i = 0;
        while(i < num){
            let input = *std::vector::borrow(&proof, i);
            computedHash = compute_pair_hash(computedHash, input);
            i = i + 1;
        };
        computedHash
    }

    public fun verify(proof: vector<vector<u8>>, root: vector<u8>, leaf: vector<u8>): bool {
        let computedHash = leaf;
        let num = vector::length(&proof);
        let i = 0;
        while(i < num){
            let input = *std::vector::borrow(&proof, i);
            computedHash = compute_pair_hash(computedHash, input);
            i = i + 1;
        };
        if(computedHash == root){
            true
        }else{
            false
        }
    }

    #[test(creator = @0x7670e6514fc0d72e5b6296c2f82093320c23667fc6d6acf80a6df362e5306e6a)]
    fun verify_test(creator: &signer) {
        use std::bcs;
        use std::signer;
        let addr = bcs::to_bytes(&signer::address_of(creator));
        let leaf = keccak256(addr);

        let root_hash = x"5ec1861c48518f41c3d4d037af879ff153a49ecd6d942796e8036ae485fcb167";
        let outputs = vector[
            x"e88176581997066a6f90328a7495d2860869e47f2a58809e5e7a3d6ba37e1d16",
            x"76f84c7bee269b2d2b8dea74bedb1fd3e9dfcc9e8d12877e634fb9943aa22eb2",
            x"e202fd9d55981efbf6bf465b5787143b338e25f36103ba738681f51a9cb72ca5",
            x"98b3e742956d835c9193ff889d7e0c9f6ac2ce12307e53e79212a6fbb73f36a7",
            x"369c846646e8c234fa9968a82172cd52871bacece44df479ef160b2ef7685589",
        ];

        assert!(verify(outputs, root_hash, leaf), 1);
        assert!(get_root_hash(outputs, leaf) == root_hash, 2);
    }
}
