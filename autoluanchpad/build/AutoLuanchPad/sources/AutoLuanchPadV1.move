module ItsRare::AutoLuanchPadV1 {
    use std::signer;
    use std::vector;
    use std::bcs;
    use std::string::{Self,String};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_framework::account::{SignerCapability, create_resource_account, create_signer_with_capability};
    use aptos_token::token::{Self};
    use aptos_std::table::{Self, Table};
    use aptos_std::comparator::{is_equal, compare_u8_vector};
    use aptos_framework::timestamp;
    use aptos_std::math64::average;
    use aptos_std::aptos_hash::{keccak256, sip_hash_from_value};
    use ItsRare::Proof::{get_root_hash};

    const EROYALTY_TOO_HIGH: u64 = 0;
    const EITSRARE_NOT_INIT: u64 = 1;
    const EITSRARE_NOT_OWNER: u64 = 2;
    const EITSRARE_NOT_COLLECTION: u64 = 3;
    const EITSRARE_NOT_CREATECOLLECTION: u64 = 4;
    const EITSRARE_EXCEED_SUPPLY: u64 = 5;
    const EITSRARE_NOT_OPENTIME: u64 = 6;
    const EITSRARE_TIME_NOT_SUITABLE: u64 = 7;
    const EITSRARE_WHITELIST_LENGTH_ERROR: u64 = 8;
    const EITSRARE_EXCEED_MAXCOUNT_ONETIME: u64 = 9;
    const EITSRARE_NOTIN_DISCOUNTLIST: u64 = 10;
    const EITSRARE_EXCEED_MAXCOUNT: u64 = 11;
    const EITSRARE_TIME_NOTMATCH: u64 = 12;
    const EITSRARE_NOT_ENOUGH_MINT: u64 = 13;
    const EITSRARE_NOT_COLLECTION_OWNER: u64 = 14;

    struct DiscountConfig has copy, drop, store {
        start_time: u64,
        end_time: u64,
        proof_root: vector<u8>,
        whitelist_url: String,
        price: u64,
        max_count_per_user: u64,
        minted: SimpleMap<address, u64>,
        already_mint: u64,
        max_count: u64,
    }

    struct CollectionConfig has copy, drop, store {
        owner: address,
        collection_owner: address,
        name: String,
        desc: String,
        collection_uri: String,
        prefix_url: String,
        website: String,
        twitter: String,
        discord: String,
        telegram: String,
        medium: String,
        start_time: u64,
        end_time: u64,
        public_price: u64,
        maxcount_onetime: u64,
        bWhitelist: bool,
        discount_vec: vector<DiscountConfig>,
        supply: u64,
        public_allowed_mint: u64,
        maximum: u64,
        num_available_tokens: u64,
        available_tokens: SimpleMap<u64, u64>,
        royalty_payee_address: address,
        royalty_points_denominator: u64,
        royalty_points_numerator:   u64,
    }

    struct CollectionId has copy, drop, store {
        collection_creator: address,
        collection_name: String,
    }

    struct TokenCap has key {
        capTab: Table<address, SignerCapability>,
        allCollectionId: vector<CollectionId>,
        collectionConfig: Table<CollectionId, CollectionConfig>,
        
        create_luanchpad_fee: u64,
        mint_fee_denominator: u64,
        mint_fee_numerator:   u64,
        mintFeeFundAddr: address,
    }

    fun u64ToString(index: u64): vector<u8> {
        let tmpNum = index;
        let res = vector::empty<u8>();
        if( tmpNum == 0 ){
            vector::push_back(&mut res, 48);
        }else{
            while(tmpNum > 0){
                let tmp:u8 = (tmpNum % 10 + 48 as u8);
                vector::push_back(&mut res, tmp);
                tmpNum = tmpNum / 10;
            };
        };
        vector::reverse(&mut res);
        res
    }

    fun mint_token(creator: &signer, owner: address, collection_owner:address, collection_name:String, amount: u64): u64 acquires TokenCap {
        assert!(exists<TokenCap>(@ItsRare), EITSRARE_NOT_INIT);
        let data = borrow_global_mut<TokenCap>(@ItsRare);
        let collection_id = create_collection_id(collection_owner, collection_name);
        assert!(table::contains(&data.collectionConfig, collection_id), EITSRARE_NOT_COLLECTION);
        let collConfig = table::borrow_mut(&mut data.collectionConfig, collection_id);

        let default_keys = vector<String>[];
        let default_vals = vector<vector<u8>>[];
        let default_types = vector<String>[];
        let mutate_setting = vector<bool>[ false, false, false, false, false, false ];

        let token_mut_config = token::create_token_mutability_config(&mutate_setting);
        let signerCapability = table::borrow(&data.capTab, owner);
        let initOwner = create_signer_with_capability(signerCapability);
        
        let index = 0;
        let available_tokens_num = collConfig.num_available_tokens;
        let account = signer::address_of(creator);
        let bash_hash_u64: u64 = sip_hash_from_value(&account) + timestamp::now_microseconds();
        let ret = 0;
        while(index < amount) {
            let num_hash_u64 = sip_hash_from_value(&available_tokens_num);
            let random_index: u64 = average(bash_hash_u64, num_hash_u64) % available_tokens_num;
            let final_index = if(!simple_map::contains_key(&collConfig.available_tokens, &random_index)){
                random_index
            }else{
                *simple_map::borrow(&collConfig.available_tokens, &random_index)
            };
            let last_index: u64 = available_tokens_num - 1;
            if(random_index != last_index){
                let update_val = if(simple_map::contains_key(&collConfig.available_tokens, &last_index)){
                    *simple_map::borrow(&collConfig.available_tokens, &last_index)
                }else{
                    last_index
                };
                if(simple_map::contains_key(&collConfig.available_tokens, &random_index)){
                    let mut = simple_map::borrow_mut(&mut collConfig.available_tokens, &random_index);
                    *mut = update_val;
                }else{
                    simple_map::add(&mut collConfig.available_tokens, random_index, update_val);
                }
            };
            if(simple_map::contains_key(&collConfig.available_tokens, &last_index)){
                simple_map::remove(&mut collConfig.available_tokens, &last_index);
            };

            let token_uri = collConfig.prefix_url;
            string::append(&mut token_uri, string::utf8(u64ToString(final_index + 1)));
            string::append(&mut token_uri, string::utf8(b".json"));

            let token_name = collection_name;
            string::append(&mut token_name, string::utf8(b" #"));
            string::append(&mut token_name, string::utf8(u64ToString(final_index)));

            let tokendata_id = token::create_tokendata(
                &initOwner,
                collection_name,
                token_name,
                collConfig.desc,
                1,
                token_uri,
                collConfig.royalty_payee_address,
                collConfig.royalty_points_denominator,
                collConfig.royalty_points_numerator,
                token_mut_config,
                default_keys,
                default_vals,
                default_types
            );

            let token_id = token::mint_token(
                &initOwner,
                tokendata_id,
                1,
            );

            let token = token::withdraw_token(&initOwner, token_id, 1);
            token::deposit_token(creator, token);
            available_tokens_num = available_tokens_num - 1;
            index = index + 1;
            ret = final_index;
        };
        collConfig.num_available_tokens = available_tokens_num;
        collConfig.supply = collConfig.supply + amount;
        ret
    }
    
    public entry fun discount_mint(
        creator: &signer,
        owner: address,
        collection_Owner: address,
        collection_name: String,
        amount: u64,
        proof: vector<vector<u8>>,
    ) acquires TokenCap {
        assert!(exists<TokenCap>(@ItsRare), EITSRARE_NOT_INIT);
        let data = borrow_global_mut<TokenCap>(@ItsRare);
        assert!(table::contains(&data.capTab, owner), EITSRARE_NOT_CREATECOLLECTION);
        let collection_id = create_collection_id(collection_Owner, collection_name);
        assert!(table::contains(&data.collectionConfig, collection_id), EITSRARE_NOT_COLLECTION);
        let collConfig = table::borrow_mut(&mut data.collectionConfig, collection_id);
        assert!(collConfig.supply < collConfig.maximum, EITSRARE_EXCEED_SUPPLY);
        assert!(collConfig.owner == owner, EITSRARE_NOT_COLLECTION_OWNER);

        let addr = bcs::to_bytes(&signer::address_of(creator));
        let leaf = keccak256(addr);
        let root_hash = get_root_hash(proof, leaf);
        let len = vector::length(&collConfig.discount_vec);
        let price = collConfig.public_price;
        let i = 0;
        let bDiscount = false;
        while(i < len){
            let config = vector::borrow_mut(&mut collConfig.discount_vec, i);
            if(config.start_time < timestamp::now_microseconds() 
                && timestamp::now_microseconds() < config.end_time 
                && is_equal(&compare_u8_vector(root_hash, config.proof_root))){
                    assert!(amount <= config.max_count, EITSRARE_EXCEED_MAXCOUNT);
                    assert!(config.already_mint + amount <= config.max_count, EITSRARE_NOT_ENOUGH_MINT);
                    if(simple_map::contains_key(&config.minted, &signer::address_of(creator))){
                        let minted_num = simple_map::borrow_mut(&mut config.minted, &signer::address_of(creator));
                        assert!(*minted_num + amount <= config.max_count_per_user, EITSRARE_EXCEED_MAXCOUNT);
                        *minted_num = *minted_num + amount;
                    }else{
                        simple_map::add(&mut config.minted, signer::address_of(creator), amount);
                    };
                    bDiscount = true;
                    price = config.price;
                    config.already_mint = config.already_mint + amount;
                    break
            };
            i = i + 1;
        };
        assert!(bDiscount, EITSRARE_NOTIN_DISCOUNTLIST);

        if(price > 0){
            let total_cost = price * amount;
            let mint_fee = if (
                data.mint_fee_denominator > 0 
                && data.mint_fee_numerator > 0
            ) {
                total_cost * data.mint_fee_numerator / data.mint_fee_denominator
            } else {
                0
            };
            if(mint_fee > 0){
                coin::transfer<AptosCoin>(creator, data.mintFeeFundAddr, mint_fee);
            };
            coin::transfer<AptosCoin>(creator, collConfig.owner, total_cost - mint_fee);
        };

        mint_token(creator, owner, collection_Owner, collection_name, amount);
    }

    // public mint
    public entry fun public_mint(
        creator: &signer,
        owner: address,
        collection_Owner: address,
        collection_name: String,
        amount: u64,
    ) acquires TokenCap {
        assert!(exists<TokenCap>(@ItsRare), EITSRARE_NOT_INIT);
        let data = borrow_global<TokenCap>(@ItsRare);
        assert!(table::contains(&data.capTab, owner), EITSRARE_NOT_CREATECOLLECTION);

        let collection_id = create_collection_id(collection_Owner, collection_name);
        assert!(table::contains(&data.collectionConfig, collection_id), EITSRARE_NOT_COLLECTION);

        let collConfig = table::borrow(&data.collectionConfig, collection_id);
        assert!(collConfig.owner == owner, EITSRARE_NOT_COLLECTION_OWNER);
        assert!(collConfig.supply + amount <= collConfig.public_allowed_mint, EITSRARE_NOT_ENOUGH_MINT);
        assert!(amount <= collConfig.maxcount_onetime, EITSRARE_EXCEED_MAXCOUNT_ONETIME);
        assert!(collConfig.start_time < timestamp::now_microseconds() 
             && timestamp::now_microseconds() < collConfig.end_time, EITSRARE_NOT_OPENTIME);
        
        if(collConfig.public_price > 0){
            let total_cost = collConfig.public_price * amount;
            let mint_fee = if (
                data.mint_fee_denominator > 0 
                && data.mint_fee_numerator > 0
            ) {
                total_cost * data.mint_fee_numerator / data.mint_fee_denominator
            } else {
                0
            };
            if(mint_fee > 0){
                coin::transfer<AptosCoin>(creator, data.mintFeeFundAddr, mint_fee);
            };
            coin::transfer<AptosCoin>(creator, collConfig.owner, total_cost - mint_fee);
        };

        mint_token(creator, owner, collection_Owner, collection_name, amount);
    }

    public entry fun mint_left(
        creator: &signer,
        owner: address,
        collection_Owner: address,
        collection_name: String,
        amount: u64,
    ) acquires TokenCap {
        assert!(exists<TokenCap>(@ItsRare), EITSRARE_NOT_INIT);
        let data = borrow_global_mut<TokenCap>(@ItsRare);
        assert!(table::contains(&data.capTab, owner), EITSRARE_NOT_CREATECOLLECTION);

        let collection_id = create_collection_id(collection_Owner, collection_name);
        assert!(table::contains(&data.collectionConfig, collection_id), EITSRARE_NOT_COLLECTION);

        let collConfig = table::borrow_mut(&mut data.collectionConfig, collection_id);
        assert!(collConfig.supply + amount <= collConfig.maximum, EITSRARE_EXCEED_SUPPLY);
        assert!(collConfig.owner == owner, EITSRARE_NOT_COLLECTION_OWNER);
        assert!(collConfig.owner == signer::address_of(creator), EITSRARE_NOT_COLLECTION_OWNER);

        mint_token(creator, owner, collection_Owner, collection_name, amount);
    }

    public entry fun init(
        creator: &signer,
        fund_address: address,
        denominator: u64,
        numerator: u64,
        luanchpad_fee: u64,
    ) acquires TokenCap {
        assert!(signer::address_of(creator) == @ItsRare, EITSRARE_NOT_OWNER);
        if (!exists<TokenCap>(signer::address_of(creator))) {
            move_to(
                creator,
                TokenCap {
                    capTab: table::new(),
                    allCollectionId: vector::empty<CollectionId>(),
                    collectionConfig: table::new(),
                    mint_fee_denominator: denominator,
                    mint_fee_numerator:   numerator,
                    mintFeeFundAddr: fund_address,
                    create_luanchpad_fee: luanchpad_fee
                },
            );
        }else{
            let data = borrow_global_mut<TokenCap>(@ItsRare);
            data.mint_fee_denominator = denominator;
            data.mint_fee_numerator = numerator;
            data.mintFeeFundAddr = fund_address;
            data.create_luanchpad_fee = luanchpad_fee;
        }
    }

    public entry fun createCollection(
        creator: &signer,
        name: String,
        desc: String,
        collection_uri: String,
        prefix_url: String,
        website: String,
        twitter: String,
        discord: String,
        medium: String,
        telegram: String,
        start_time: u64,
        end_time: u64,
        public_price: u64,
        maxcount_onetime: u64,
        bWhitelist: bool,
        discount_start_time: vector<u64>,
        discount_end_time: vector<u64>,
        discount_proof_root: vector<vector<u8>>,
        discount_whitelist_url: vector<String>,
        discount_price: vector<u64>,
        discount_max_count_peruser: vector<u64>,
        discount_max_count: vector<u64>,
        public_allowed_mint: u64,
        maximum: u64,
        royalty_payee_address: address,
        royalty_ratio: u64,
    ) acquires TokenCap {
        assert!(royalty_ratio <= 1000 && public_allowed_mint <= maximum, EROYALTY_TOO_HIGH);
        assert!(exists<TokenCap>(@ItsRare),EITSRARE_NOT_INIT);
        assert!(vector::length(&discount_start_time) == vector::length(&discount_end_time)
                && vector::length(&discount_proof_root) == vector::length(&discount_end_time)
                && vector::length(&discount_proof_root) == vector::length(&discount_whitelist_url)
                && vector::length(&discount_whitelist_url) == vector::length(&discount_max_count)
                && vector::length(&discount_price) == vector::length(&discount_max_count_peruser), EITSRARE_WHITELIST_LENGTH_ERROR);
        
        let data = borrow_global_mut<TokenCap>(@ItsRare);
        coin::transfer<AptosCoin>(creator, data.mintFeeFundAddr, data.create_luanchpad_fee);
        let discount_vec = vector::empty<DiscountConfig>();
        let i = 0;
        let num = vector::length(&discount_start_time);
        while(i < num){
            let start_time = *vector::borrow(&discount_start_time, i);
            let end_time = *vector::borrow(&discount_end_time, i);
            assert!(start_time < end_time, EITSRARE_TIME_NOTMATCH);
            if(i > 0){
                assert!(start_time >= *vector::borrow(&discount_end_time, i-1), EITSRARE_TIME_NOTMATCH);
            };
            let config = DiscountConfig {
                start_time,
                end_time,
                proof_root: *vector::borrow(&discount_proof_root, i),
                whitelist_url: *vector::borrow(&discount_whitelist_url, i),
                price: *vector::borrow(&discount_price, i),
                max_count_per_user: *vector::borrow(&discount_max_count_peruser, i),
                minted: simple_map::create(),
                already_mint: 0,
                max_count: *vector::borrow(&discount_max_count, i),
            };
            vector::push_back(&mut discount_vec, config);
            i = i + 1;
        };

        let account = signer::address_of(creator);
        if( table::contains(&data.capTab, account) ){
            let signerCapability = table::borrow(&data.capTab, account);
            let initOwner = create_signer_with_capability(signerCapability);
            let del_account = signer::address_of(&initOwner);
            let collection_id = create_collection_id(del_account, name);
            table::add(&mut data.collectionConfig, collection_id, CollectionConfig {
                owner: account,
                collection_owner: del_account,
                name,
                desc,
                collection_uri,
                prefix_url,
                website,
                twitter,
                discord,
                medium,
                telegram,
                start_time,
                end_time,
                public_price,
                maxcount_onetime,
                bWhitelist,
                discount_vec,
                supply: 0,
                public_allowed_mint,
                maximum,
                num_available_tokens: maximum,
                available_tokens: simple_map::create(),
                royalty_payee_address: royalty_payee_address,
                royalty_points_denominator: 10000,
                royalty_points_numerator:   royalty_ratio,
            });
            vector::push_back(&mut data.allCollectionId, collection_id);

            let mutate_setting = vector<bool>[false, false, false];
            token::create_collection(
                &initOwner,
                name,
                desc,
                collection_uri,
                maximum,
                mutate_setting
            );
        }else{
            let (sign, capbility) = create_resource_account(creator, x"01");
            let del_account = signer::address_of(&sign);
            table::add(&mut data.capTab, account, capbility);

            let collection_id = create_collection_id(del_account, name);
            assert!(!table::contains(&data.collectionConfig, collection_id), 1);

            table::add(&mut data.collectionConfig, collection_id, CollectionConfig {
                owner: account,
                collection_owner: del_account,
                name,
                desc,
                collection_uri,
                prefix_url,
                website,
                twitter,
                discord,
                medium,
                telegram,
                start_time,
                end_time,
                public_price,
                maxcount_onetime,
                bWhitelist,
                discount_vec,
                supply: 0,
                public_allowed_mint,
                maximum,
                num_available_tokens: maximum,
                available_tokens: simple_map::create(),
                royalty_payee_address: royalty_payee_address,
                royalty_points_denominator: 10000,
                royalty_points_numerator:   royalty_ratio,
            });
            vector::push_back(&mut data.allCollectionId, collection_id);

            let mutate_setting = vector<bool>[false, false, false];
            token::create_collection(
                &sign,
                name,
                desc,
                collection_uri,
                maximum,
                mutate_setting
            );
        };
    }

    public fun create_collection_id(collection_creator: address, collection_name: String): CollectionId {
        CollectionId{
            collection_creator,
            collection_name,
        }
    }

    public fun get_collection_owner_addr(
        owner: address,
    ): address acquires TokenCap {
        let data = borrow_global_mut<TokenCap>(@ItsRare);
        let signerCapability = table::borrow(&data.capTab, owner);
        let initOwner = create_signer_with_capability(signerCapability);
        let del_account = signer::address_of(&initOwner);
        del_account
    }

    #[test(initor = @ItsRare, creator = @0xAF, minter = @0xBB, framework = @0x1)]
    public entry fun create_collection_and_token(
        creator: &signer,
        minter: &signer,
        initor: &signer,
        framework: &signer,
    ) acquires TokenCap {
        use std::string;
        use aptos_std::debug;

        let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(framework);
        aptos_framework::aptos_account::create_account(signer::address_of(creator));
        aptos_framework::aptos_account::create_account(signer::address_of(minter));
        aptos_framework::aptos_account::create_account(signer::address_of(initor));
        coin::deposit(signer::address_of(minter), coin::mint(1000000000, &mint_cap));
        coin::deposit(signer::address_of(creator), coin::mint(1000000000, &mint_cap));
        coin::deposit(signer::address_of(initor), coin::mint(1000000000, &mint_cap));

        token::initialize_token_store(creator);
        token::initialize_token_store(minter);
        token::initialize_token_store(initor);

        timestamp::set_time_has_started_for_testing(framework);

        init(
            initor,
            @ItsRare,
            10000,
            300,
        );

        createCollection(
            creator,
            string::utf8(b"Collection: Hello, World"),
            string::utf8(b"Collection: DESC"),
            string::utf8(b"https://aptos.dev"),
            string::utf8(b"https://aptos.dev111"),
            1666856118,
            1666858000,
            100000000,
            5,
            false,
            vector<u64>[],
            vector<u64>[],
            vector<vector<u8>>[],
            vector<String>[],
            vector<u64>[],
            vector<u64>[],
            vector<u64>[],
            10,
            10,
            signer::address_of(creator),
            500,
        );
        timestamp::update_global_time_for_test(1666857001);

        // public_mint(
        //     minter,
        //     signer::address_of(creator),
        //     get_collection_owner_addr(signer::address_of(creator)),
        //     string::utf8(b"Collection: Hello, World"),
        //     1
        // );
        let i = 0;
        while(i < 10){
            let index = mint_token(
                minter,
                signer::address_of(creator),
                get_collection_owner_addr(signer::address_of(creator)),
                string::utf8(b"Collection: Hello, World"),
                1
            );
            debug::print(&index);
            i = i + 1;
        };
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
}