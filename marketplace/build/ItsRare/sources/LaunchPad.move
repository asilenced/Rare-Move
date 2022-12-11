module ItsRare::LaunchPad {
    use std::signer;
    use std::vector;
    use std::error;
    use std::string::{Self,String};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::account::{SignerCapability, create_resource_account, create_signer_with_capability};
    use aptos_token::token::{Self};
    use aptos_std::table::{Self, Table};
    use aptos_framework::timestamp;

    const EROYALTY_TOO_HIGH: u64 = 0;
    const EITSRARE_NOT_INIT: u64 = 1;
    const EITSRARE_NOT_OWNER: u64 = 2;
    const EITSRARE_NOT_COLLECTION: u64 = 3;
    const EITSRARE_NOT_CREATECOLLECTION: u64 = 4;
    const EITSRARE_EXCEED_SUPPLY: u64 = 5;
    const EITSRARE_NOT_OPENTIME: u64 = 6;
    const EDEPRECATED_MODULE: u64 = 7;

    struct CollectionConfig has copy, drop, store {
        owner: address,
        collection_owner: address,
        name: String,
        desc: String,
        uri: String,
        website: String,
        twitter: String,
        discord: String,
        telegram: String,
        json_uri: String,
        prefix_url: String,
        suffix_uri: String,
        start_time: u64,
        end_time: u64,
        mint_price: u64,
        supply: u64,
        maximum: u64,
        royalty_payee_address: address,
        royalty_points_denominator: u64,
        royalty_points_numerator:   u64,
    }

    struct CollectionId has copy, drop, store {
        // The creator of this collection
        collection_creator: address,
        // The collection or set of related tokens within the creator's account
        collection_name: String,
    }

    struct TokenCap has key {
        capTab: Table<address, SignerCapability>,
        allCollectionId: vector<CollectionId>,
        collectionConfig: Table<CollectionId, CollectionConfig>,
        
        royalty_points_denominator: u64,
        royalty_points_numerator:   u64,
        mintFeeAddr: address,
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
    
    /// Token owner lists their token for swapping
    public entry fun mint(
        creator: &signer,
        owner: address,
        collection_Owner: address,
        collection_name: String,
        amount: u64,
    ) {
        abort error::invalid_argument(EDEPRECATED_MODULE)
        // assert!(exists<TokenCap>(@ItsRare), EITSRARE_NOT_INIT);
        // let data = borrow_global_mut<TokenCap>(@ItsRare);
        // assert!(table::contains(&data.capTab, owner), EITSRARE_NOT_CREATECOLLECTION);

        // let collection_id = create_collection_id(collection_Owner, collection_name);
        // assert!(table::contains(&data.collectionConfig, collection_id), EITSRARE_NOT_COLLECTION);

        // let collConfig = table::borrow_mut(&mut data.collectionConfig, collection_id);
        // assert!(collConfig.supply < collConfig.maximum, EITSRARE_EXCEED_SUPPLY);
        // assert!(collConfig.start_time < timestamp::now_microseconds() 
        //        && timestamp::now_microseconds() < collConfig.end_time, EITSRARE_NOT_OPENTIME);
        // if(collConfig.mint_price > 0){
        //     let total_cost = collConfig.mint_price * amount;
        //     let royalty_fee = if (
        //         data.royalty_points_denominator > 0 
        //         && data.royalty_points_numerator > 0
        //     ) {
        //         total_cost * data.royalty_points_numerator / data.royalty_points_denominator
        //     } else {
        //         0
        //     };
        //     if(royalty_fee > 0){
        //         coin::transfer<AptosCoin>(creator, data.mintFeeAddr, royalty_fee);
        //     };
        //     coin::transfer<AptosCoin>(creator, collConfig.owner, total_cost - royalty_fee);
        // };
        // let final_index = collConfig.supply;
        // let photo_index = collConfig.supply + 1;
        // let token_uri = collConfig.prefix_url;
        // let suf_uri = collConfig.suffix_uri;
        // string::append(&mut token_uri, string::utf8(u64ToString(photo_index)));
        // string::append(&mut token_uri, suf_uri);

        // collConfig.supply = collConfig.supply + 1;

        // let default_keys = vector<String>[];
        // let default_vals = vector<vector<u8>>[];
        // let default_types = vector<String>[];
        // let mutate_setting = vector<bool>[ false, false, false, false, false, false ];

        // let token_mut_config = token::create_token_mutability_config(&mutate_setting);
        // let signerCapability = table::borrow(&data.capTab, owner);
        // let initOwner = create_signer_with_capability(signerCapability);

        // let tokendata_id = token::create_tokendata(
        //     &initOwner,
        //     collection_name,
        //     string::utf8(u64ToString(final_index)),
        //     collConfig.desc,
        //     1,
        //     token_uri,
        //     collConfig.royalty_payee_address,
        //     collConfig.royalty_points_denominator,
        //     collConfig.royalty_points_numerator,
        //     token_mut_config,
        //     default_keys,
        //     default_vals,
        //     default_types
        // );

        // let token_id = token::mint_token(
        //     &initOwner,
        //     tokendata_id,
        //     1,
        // );

        // let token = token::withdraw_token(&initOwner, token_id, 1);
        // token::deposit_token(creator, token);
    }

    public entry fun init(
        creator: &signer,
    ) {
        assert!(signer::address_of(creator) == @ItsRare, EITSRARE_NOT_OWNER);
        if (!exists<TokenCap>(signer::address_of(creator))) {
            move_to(
                creator,
                TokenCap {
                    capTab: table::new(),
                    allCollectionId: vector::empty<CollectionId>(),
                    collectionConfig: table::new(),
                    royalty_points_denominator: 10000,
                    royalty_points_numerator:   200,
                    mintFeeAddr: signer::address_of(creator)
                },
            );
        };
    }

    public entry fun createCollection(
        creator: &signer,
        name: String,
        desc: String,
        uri: String,
        website: String,
        twitter: String,
        discord: String,
        telegram: String,
        json_uri: String,
        prefix_url: String,
        suffix_uri: String,
        start_time: u64,
        end_time: u64,
        mint_price: u64,
        maximum: u64,
        royalty_payee_address: address,
        royalty_ratio: u64,
    ) {
        abort error::invalid_argument(EDEPRECATED_MODULE)
        // assert!(royalty_ratio <= 1000, EROYALTY_TOO_HIGH);
        // assert!(exists<TokenCap>(@ItsRare),EITSRARE_NOT_INIT);

        // let data = borrow_global_mut<TokenCap>(@ItsRare);
        // let account = signer::address_of(creator);
        // if( table::contains(&data.capTab, account) ){
        //     let signerCapability = table::borrow(&data.capTab, account);
        //     let initOwner = create_signer_with_capability(signerCapability);
        //     let del_account = signer::address_of(&initOwner);
        //     let collection_id = create_collection_id(del_account, name);
        //     table::add(&mut data.collectionConfig, collection_id, CollectionConfig {
        //         owner: account,
        //         collection_owner: del_account,
        //         name,
        //         desc,
        //         uri,
        //         website,
        //         twitter,
        //         discord,
        //         telegram,
        //         json_uri,
        //         prefix_url,
        //         suffix_uri,
        //         start_time,
        //         end_time,
        //         mint_price,
        //         supply: 0,
        //         maximum,
        //         royalty_payee_address: royalty_payee_address,
        //         royalty_points_denominator: 10000,
        //         royalty_points_numerator:   royalty_ratio,
        //     });
        //     vector::push_back(&mut data.allCollectionId, collection_id);

        //     let mutate_setting = vector<bool>[false, false, false];
        //     token::create_collection(
        //         &initOwner,
        //         name,
        //         desc,
        //         uri,
        //         maximum,
        //         mutate_setting
        //     );
        // }else{
        //     let (sign, capbility) = create_resource_account(creator, x"01");
        //     let del_account = signer::address_of(&sign);
        //     table::add(&mut data.capTab, account, capbility);

        //     let collection_id = create_collection_id(del_account, name);
        //     assert!(!table::contains(&data.collectionConfig, collection_id), 1);

        //     table::add(&mut data.collectionConfig, collection_id, CollectionConfig {
        //         owner: account,
        //         collection_owner: del_account,
        //         name,
        //         desc,
        //         uri,
        //         website,
        //         twitter,
        //         discord,
        //         telegram,
        //         json_uri,
        //         prefix_url,
        //         suffix_uri,
        //         start_time,
        //         end_time,
        //         mint_price,
        //         supply: 0,
        //         maximum,
        //         royalty_payee_address: royalty_payee_address,
        //         royalty_points_denominator: 10000,
        //         royalty_points_numerator:   royalty_ratio,
        //     });
        //     vector::push_back(&mut data.allCollectionId, collection_id);

        //     let mutate_setting = vector<bool>[false, false, false];
        //     token::create_collection(
        //         &sign,
        //         name,
        //         desc,
        //         uri,
        //         maximum,
        //         mutate_setting
        //     );
        // };
    }

    public fun create_collection_id(collection_creator: address, collection_name: String): CollectionId {
        CollectionId{
            collection_creator,
            collection_name,
        }
    }
}