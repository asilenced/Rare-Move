module ItsRare::MarketPlace {
    use std::signer;
    use std::vector;
    use std::string::{String};
    use aptos_token::token::{Self, TokenId};
    use aptos_std::table::{Self, Table};
    use ItsRare::Events;
    use ItsRare::token_coin_swap;

    const EITSRARE_NOT_OWNER: u64 = 0;
    const EITSRARE_NOT_INITLIST: u64 = 1;
    const EITSRARE_NOT_INITINDEX: u64 = 2;
    const EITSRARE_NOT_TOKENID: u64 = 3;
    const EITSRARE_NOT_TOKENOWNER: u64 = 4;
    const EITSRARE_VECTOR_LENGTHERROR: u64 = 5;

    struct Index has key {
        book: Table<TokenId, u64>,
        listings: Table<address, vector<u64>>,
    }

    struct Listing has drop, store {
        listing_id: u64,
        token_id: TokenId,
        seller: address,
        price: u64,
        amount: u64,
    }

    struct Listings has key {
        nonce: u64,
        listings: Table<u64, Listing>,
    }

    public entry fun init(
        creator: &signer
    ) {
        let account = signer::address_of(creator);
        assert!(account == @ItsRare, EITSRARE_NOT_OWNER);

        if (!exists<Listings>(signer::address_of(creator))) {
            move_to(
                creator,
                Listings {
                    nonce: 0,
                    listings: table::new(),
                },
            );
        };

        if (!exists<Index>(signer::address_of(creator))) {
            move_to(
                creator,
                Index {
                    book: table::new(),
                    listings: table::new(),
                },
            );
        }
    }

    public entry fun list<CoinType>(
        lister: &signer,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64,
        amount: u64,
        price: u64
    ) acquires Listings, Index {
        assert!(exists<Listings>(@ItsRare), EITSRARE_NOT_INITLIST);
        assert!(exists<Index>(@ItsRare), EITSRARE_NOT_INITINDEX);
        
        let listingsdata = borrow_global_mut<Listings>(@ItsRare);
        assert!(!table::contains(&listingsdata.listings, listingsdata.nonce), 0);

        token_coin_swap::list_token_for_swap<CoinType>(
            lister,
            creators_address,
            collection,
            name,
            property_version,
            amount,
            price,
            0
        );

        let seller = signer::address_of(lister);
        let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
        if( !table::contains(&listingsdata.listings, listingsdata.nonce) ){
            table::add(&mut listingsdata.listings, listingsdata.nonce, Listing {
                listing_id: listingsdata.nonce,
                token_id,
                seller,
                price,
                amount,     
            });
        };
        
        let indexdata = borrow_global_mut<Index>(@ItsRare);
        table::upsert(&mut indexdata.book, token_id, listingsdata.nonce);

        if(!table::contains(&indexdata.listings, seller)){
            table::add(&mut indexdata.listings, seller, vector::empty<u64>());
        };
        let vecIndex = table::borrow_mut(&mut indexdata.listings, seller);
        vector::push_back(vecIndex, listingsdata.nonce);

        Events::list_event<CoinType>(
            listingsdata.nonce,
            token_id,
            seller,
            price,
            amount,
        );
        listingsdata.nonce = listingsdata.nonce + 1;
    }

    public entry fun delist<CoinType>(
        delister: &signer,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64,
        amount: u64
    ) acquires Listings, Index {
        assert!(exists<Listings>(@ItsRare), EITSRARE_NOT_INITLIST);
        assert!(exists<Index>(@ItsRare), EITSRARE_NOT_INITINDEX);

        let seller = signer::address_of(delister);
        let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
        let indexdata = borrow_global_mut<Index>(@ItsRare);
        assert!(table::contains(&indexdata.book, token_id), EITSRARE_NOT_TOKENID);
        let list_id = table::remove(&mut indexdata.book, token_id);
        let listingsdata = borrow_global_mut<Listings>(@ItsRare);
        let list_info = table::borrow(&listingsdata.listings, list_id);

        token_coin_swap::cancel_token_listing<CoinType>(
            delister,
            token_id,
            amount
        );

        Events::delist_event<CoinType>(
            list_id,
            token_id,
            seller,
            list_info.price,
            amount,
        );
    }

    public entry fun buy<CoinType>(
        buyer: &signer,
        token_owner: address,
        coin_amount: u64,
        amount: u64,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64
    ) acquires Listings, Index {
        assert!(exists<Listings>(@ItsRare), EITSRARE_NOT_INITLIST);
        assert!(exists<Index>(@ItsRare), EITSRARE_NOT_INITINDEX);

        let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
        let indexdata = borrow_global_mut<Index>(@ItsRare);
        assert!(table::contains(&indexdata.book, token_id), EITSRARE_NOT_TOKENID);

        let list_id = table::borrow(&indexdata.book, token_id);
        let listingsdata = borrow_global<Listings>(@ItsRare);
        let list_info = table::borrow(&listingsdata.listings, *list_id);
        assert!(token_owner == list_info.seller, EITSRARE_NOT_TOKENOWNER);

        token_coin_swap::exchange_coin_for_token<CoinType>(
            buyer,
            coin_amount,
            token_owner,
            creators_address,
            collection,
            name,
            property_version,
            amount,
        );
        Events::buy_event<CoinType>(
            *list_id,
            token_id,
            list_info.price,
            amount,
            token_owner,
            signer::address_of(buyer),
        );
    }

    public entry fun list_many<CoinType>(
        lister: &signer,
        creators_address: vector<address>,
        collection: vector<String>,
        name: vector<String>,
        property_version: vector<u64>,
        amount: vector<u64>,
        price: vector<u64>
    ) acquires Listings, Index {
        assert!(exists<Listings>(@ItsRare), EITSRARE_NOT_INITLIST);
        assert!(exists<Index>(@ItsRare), EITSRARE_NOT_INITINDEX);
        assert!(vector::length(&creators_address) == vector::length(&collection)
                && vector::length(&name) == vector::length(&property_version)
                && vector::length(&amount) == vector::length(&price)
                && vector::length(&collection) == vector::length(&name)
                && vector::length(&price) == vector::length(&property_version), EITSRARE_VECTOR_LENGTHERROR);
        
        let listingsdata = borrow_global_mut<Listings>(@ItsRare);
        assert!(!table::contains(&listingsdata.listings, listingsdata.nonce), 0);
        let seller = signer::address_of(lister);
        let indexdata = borrow_global_mut<Index>(@ItsRare);
        if(!table::contains(&indexdata.listings, seller)){
            table::add(&mut indexdata.listings, seller, vector::empty<u64>());
        };

        let i = 0;
        let len = vector::length(&name);
        while(i < len){
            let creators_address = *vector::borrow(&creators_address, i);
            let collection = *vector::borrow(&collection, i);
            let name = *vector::borrow(&name, i);
            let property_version = *vector::borrow(&property_version, i);
            let amount = *vector::borrow(&amount, i);
            let price = *vector::borrow(&price, i);
            token_coin_swap::list_token_for_swap<CoinType>(
                lister,
                creators_address,
                collection,
                name,
                property_version,
                amount,
                price,
                0
            );
            let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
            if( !table::contains(&listingsdata.listings, listingsdata.nonce) ){
                table::add(&mut listingsdata.listings, listingsdata.nonce, Listing {
                    listing_id: listingsdata.nonce,
                    token_id,
                    seller,
                    price,
                    amount,     
                });
            };
            let vecIndex = table::borrow_mut(&mut indexdata.listings, seller);
            vector::push_back(vecIndex, listingsdata.nonce);
            table::upsert(&mut indexdata.book, token_id, listingsdata.nonce);
            Events::list_event<CoinType>(
                listingsdata.nonce,
                token_id,
                seller,
                price,
                amount,
            );
            listingsdata.nonce = listingsdata.nonce + 1;
            i = i + 1;
        }
    }

    public entry fun delist_many<CoinType>(
        delister: &signer,
        creators_address: vector<address>,
        collection: vector<String>,
        name: vector<String>,
        property_version: vector<u64>,
        amount: vector<u64>
    ) acquires Listings, Index {
        assert!(exists<Listings>(@ItsRare), EITSRARE_NOT_INITLIST);
        assert!(exists<Index>(@ItsRare), EITSRARE_NOT_INITINDEX);
        assert!(vector::length(&creators_address) == vector::length(&collection)
                && vector::length(&name) == vector::length(&property_version)
                && vector::length(&amount) == vector::length(&collection)
                && vector::length(&collection) == vector::length(&name), EITSRARE_VECTOR_LENGTHERROR);
        
        let seller = signer::address_of(delister);
        let indexdata = borrow_global_mut<Index>(@ItsRare);
        let listingsdata = borrow_global_mut<Listings>(@ItsRare);

        let i = 0;
        let len = vector::length(&name);
        while(i < len){
            let creators_address = *vector::borrow(&creators_address, i);
            let collection = *vector::borrow(&collection, i);
            let name = *vector::borrow(&name, i);
            let property_version = *vector::borrow(&property_version, i);
            let amount = *vector::borrow(&amount, i);
            let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
            assert!(table::contains(&indexdata.book, token_id), EITSRARE_NOT_TOKENID);
            let list_id = table::remove(&mut indexdata.book, token_id);
            let list_info = table::borrow(&listingsdata.listings, list_id);
            token_coin_swap::cancel_token_listing<CoinType>(
                delister,
                token_id,
                amount
            );
            Events::delist_event<CoinType>(
                list_id,
                token_id,
                seller,
                list_info.price,
                amount,
            );
            i = i + 1;
        };
    }

    public entry fun buy_many<CoinType>(
        buyer: &signer,
        token_owner: vector<address>,
        coin_amount: vector<u64>,
        amount: vector<u64>,
        creators_address: vector<address>,
        collection: vector<String>,
        name: vector<String>,
        property_version: vector<u64>
    ) acquires Listings, Index {
        assert!(exists<Listings>(@ItsRare), EITSRARE_NOT_INITLIST);
        assert!(exists<Index>(@ItsRare), EITSRARE_NOT_INITINDEX);
        assert!(vector::length(&token_owner) == vector::length(&coin_amount)
                && vector::length(&amount) == vector::length(&creators_address)
                && vector::length(&collection) == vector::length(&name)
                && vector::length(&coin_amount) == vector::length(&amount)
                && vector::length(&property_version) == vector::length(&collection)
                && vector::length(&creators_address) == vector::length(&collection), EITSRARE_VECTOR_LENGTHERROR);

        let indexdata = borrow_global_mut<Index>(@ItsRare);
        let listingsdata = borrow_global<Listings>(@ItsRare);
        let i = 0;
        let len = vector::length(&name);
        while(i < len){
            let creators_address = *vector::borrow(&creators_address, i);
            let collection = *vector::borrow(&collection, i);
            let name = *vector::borrow(&name, i);
            let property_version = *vector::borrow(&property_version, i);
            let token_owner = *vector::borrow(&token_owner, i);
            let coin_amount = *vector::borrow(&coin_amount, i);
            let amount = *vector::borrow(&amount, i);
            
            let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
            assert!(table::contains(&indexdata.book, token_id), EITSRARE_NOT_TOKENID);
            let list_id = table::borrow(&indexdata.book, token_id);
            let list_info = table::borrow(&listingsdata.listings, *list_id);
            assert!(token_owner == list_info.seller, EITSRARE_NOT_TOKENOWNER);
            token_coin_swap::exchange_coin_for_token<CoinType>(
                buyer,
                coin_amount,
                token_owner,
                creators_address,
                collection,
                name,
                property_version,
                amount,
            );
            Events::buy_event<CoinType>(
                *list_id,
                token_id,
                list_info.price,
                amount,
                token_owner,
                signer::address_of(buyer),
            );
            i = i + 1;
        }
    }
}
