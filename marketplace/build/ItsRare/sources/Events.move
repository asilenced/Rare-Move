module ItsRare::Events {
    use std::signer;
    use aptos_framework::account;
    use std::string::{String};
    use aptos_std::event::{Self, EventHandle};
    use aptos_token::token::{TokenId};
    use aptos_std::type_info::{Self};

    friend ItsRare::LaunchPad;
    friend ItsRare::MarketPlace;

    struct ListEvent has store, drop {
        listing_id: u64,
        token_id: TokenId,
        price: u64,
        amount: u64,
        lister: address,
        coin_type_info: String,
    }

    struct DelistEvent has store, drop {
        listing_id: u64,
        token_id: TokenId,
        price: u64,
        amount: u64,
        lister: address,
        coin_type_info: String,
    }

    struct BuyEvent has store, drop {
        listing_id: u64,
        token_id: TokenId,
        price: u64,
        amount: u64,
        seller: address,
        buyer: address,
        coin_type_info: String,
    }

    struct Events has key {
        list_events: EventHandle<ListEvent>,
        delist_events: EventHandle<DelistEvent>,
        buy_events: EventHandle<BuyEvent>,
    }

    public entry fun init(
        creator: &signer
    ){
        assert!(signer::address_of(creator) == @ItsRare, 2);
        if (!exists<Events>(signer::address_of(creator))) {
            move_to(
                creator,
                Events {
                    list_events: account::new_event_handle<ListEvent>(creator),
                    delist_events: account::new_event_handle<DelistEvent>(creator),
                    buy_events: account::new_event_handle<BuyEvent>(creator),
                },
            );
        };
    }

    public(friend) fun list_event<CoinType>(
        listing_id: u64,
        token_id: TokenId,
        lister: address,
        price: u64,
        amount: u64,
    ) acquires Events {
        let event_handle = borrow_global_mut<Events>(@ItsRare);
        event::emit_event<ListEvent>(
            &mut event_handle.list_events,
            ListEvent {
                listing_id,
                token_id,
                price,
                amount,
                lister,
                coin_type_info: type_info::type_name<CoinType>(),
            },
        );
    }

    public(friend) fun delist_event<CoinType>(
        listing_id: u64,
        token_id: TokenId,
        lister: address,
        price: u64,
        amount: u64,
    ) acquires Events {
        let event_handle = borrow_global_mut<Events>(@ItsRare);
        event::emit_event<DelistEvent>(
            &mut event_handle.delist_events,
            DelistEvent {
                listing_id,
                token_id,
                price,
                amount,
                lister,
                coin_type_info: type_info::type_name<CoinType>(),
            },
        );
    }

    public(friend) fun buy_event<CoinType>(
        listing_id: u64,
        token_id: TokenId,
        price: u64,
        amount: u64,
        seller: address,
        buyer: address,
    ) acquires Events {
        let event_handle = borrow_global_mut<Events>(@ItsRare);
        event::emit_event<BuyEvent>(
            &mut event_handle.buy_events,
            BuyEvent {
                listing_id,
                token_id,
                price,
                amount,
                seller,
                buyer,
                coin_type_info: type_info::type_name<CoinType>(),
            },
        );
    }
}
