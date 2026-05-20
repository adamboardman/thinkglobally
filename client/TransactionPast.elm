module TransactionPast exposing (..)

import Bootstrap.Button as Button
import Bootstrap.Table as Table exposing (Row, rowAttr)
import Html exposing (Html, h4, text)
import Html.Attributes exposing (style)
import Http exposing (emptyBody)
import Json.Decode exposing (Decoder, list)
import TransactionCreate
import Types exposing (ApiActionResponse, Concept, ConceptTag, Model, Msg(..), Page(..), Problem(..), Transaction, TransactionForm, TransactionFromType(..), TransactionType(..), User, ValidatedField(..), authHeader, formatBalance, formatBalancePlusFee, transactionDecoder, userDecoder)


transactionSummary : Model -> Transaction -> Row Msg
transactionSummary model tx =
    let
        tgsIn =
            if model.loggedInUser.id == tx.toUserId then
                formatBalance tx.seconds

            else
                ""

        tgsOut =
            if model.loggedInUser.id == tx.fromUserId then
                if tx.status == 3 then
                    formatBalancePlusFee tx.seconds tx.txFee

                else
                    formatBalance tx.seconds

            else
                ""

        balance =
            if model.loggedInUser.id == tx.fromUserId then
                tx.fromUserBalance

            else
                tx.toUserBalance
    in
    Table.tr
        [ if tx.status > 4 then
            rowAttr (style "color" "grey")

          else
            rowAttr (style "" "")
        ]
        [ Table.td [] [ text (Types.dateFromTransaction model tx) ]
        , Table.td [] [ text (Types.transactionFromUserName model tx) ]
        , Table.td [] [ text (Types.transactionToUserName model tx) ]
        , Table.td [] [ text (Types.transactionStatus model tx) ]
        , Table.td [] [ text tgsIn ]
        , Table.td [] [ text tgsOut ]
        , Table.td [] [ text (formatBalance balance) ]
        , Table.td [] [ Button.button [ Button.primary, Button.onClick <| ViewTransaction tx.id ] [ text "View" ] ]
        ]


transactionBalancesDetailedSummary : Model -> Transaction -> List (Html Msg)
transactionBalancesDetailedSummary model tx =
    if model.page == PastTransactions then
        [ text "Transaction Balances: "
        , text (Types.transactionFromUserName model tx)
        , text ": "
        , text (formatBalance tx.fromUserBalance)
        , text ", "
        , text (Types.transactionToUserName model tx)
        , text ": "
        , text (formatBalance tx.toUserBalance)
        ]

    else
        [ text "Resultant Balances: "
        , text (Types.transactionFromUserName model tx)
        , text ": "
        , text (formatBalance (Types.transactionNewBalanceFrom model tx))
        , text ", "
        , text (Types.transactionToUserName model tx)
        , text ": "
        , text (formatBalance (Types.transactionNewBalanceTo model tx))
        ]


transactionValueDetailedSummary : Model -> Transaction -> List (Html Msg)
transactionValueDetailedSummary model tx =
    let
        locationId =
            if tx.locationId > 0 then
                tx.locationId

            else
                model.loggedInUser.locationId

        location =
            Maybe.withDefault Types.emptyLivingWageLocation (List.head (List.filter (\lwl -> locationId == lwl.id) model.livingWageLocationList))

        livingWage =
            TransactionCreate.findLivingWageForLocationIdAndDate model locationId tx.initiatedDate

        national =
            if livingWage.wage > 0 then
                " - " ++ location.name ++ ":" ++ location.symbol ++ Types.formatNationalFloat ((toFloat (Types.transactionTgsAsSeconds model tx) / 3600) * livingWage.wage)

            else
                ""
    in
    [ text "Value in TGs: "
    , text (Types.formatBalance tx.seconds)
    , text " ("
    , text (Types.timeFromTgs tx.seconds)
    , text national
    , text ")"
    ]


transactionTaxDetailedSummary : Model -> Transaction -> List (Html Msg)
transactionTaxDetailedSummary model tx =
    let
        locationId =
            if tx.locationId > 0 then
                tx.locationId

            else
                model.loggedInUser.locationId

        location =
            Maybe.withDefault Types.emptyLivingWageLocation (List.head (List.filter (\lwl -> locationId == lwl.id) model.livingWageLocationList))

        livingWage =
            TransactionCreate.findLivingWageForLocationIdAndDate model locationId tx.initiatedDate

        national =
            if livingWage.wage > 0 then
                " - " ++ location.name ++ ":" ++ location.symbol ++ Types.formatNationalTaxFloat (toFloat tx.txFee / 3600 * livingWage.wage)

            else
                ""
    in
    [ text "Tax in TGs: "
    , text (Types.formatBalance tx.txFee)
    , text " ("
    , text (Types.timeFromTgs tx.txFee)
    , text national
    , text ")"
    ]


transactionDetailedSummary : Model -> List Transaction -> List (Html Msg)
transactionDetailedSummary model txs =
    case List.head (List.filter (Types.isSelectedTx model.selectedTxId) txs) of
        Just tx ->
            [ Html.div [] [ text "Date: ", text (Types.dateFromTransaction model tx) ]
            , Html.div [] [ text "Type: ", text (Types.transactionActivity tx) ]
            , Html.div [] [ text "From: ", text (Types.transactionFromUserName model tx) ]
            , Html.div [] [ text "To: ", text (Types.transactionToUserName model tx) ]
            , Html.div [] (transactionValueDetailedSummary model tx)
            , Html.div [] (transactionTaxDetailedSummary model tx)
            , Html.div [] (transactionBalancesDetailedSummary model tx)
            , Html.div [] [ text "Status: ", text (Types.transactionStatus model tx) ]
            , Html.div [] [ text "Description: ", text tx.description ]
            ]

        Nothing ->
            [ Html.div []
                [ text "No transaction selected for detailed view"
                ]
            ]


pageTransactionList : Model -> List (Html Msg)
pageTransactionList model =
    List.concat
        [ [ h4 [] [ text "Recent Transactions" ]
          , Table.table
                { options = [ Table.striped, Table.hover ]
                , thead =
                    Table.simpleThead
                        [ Table.th [] [ text "Date" ]
                        , Table.th [] [ text "From" ]
                        , Table.th [] [ text "To" ]
                        , Table.th [] [ text "Status" ]
                        , Table.th [] [ text "TGs In" ]
                        , Table.th [] [ text "TGs Out" ]
                        , Table.th [] [ text "Balance" ]
                        , Table.th [] [ text "View" ]
                        ]
                , tbody =
                    Table.tbody []
                        (List.map
                            (transactionSummary model)
                            model.pastTransactions
                        )
                }
          , Html.br [] []
          ]
        , transactionDetailedSummary model model.pastTransactions
        , [ Html.br [] []
          , Html.br [] []
          , Html.br [] []
          , Html.br [] []
          ]
        ]



-- HTTP


loadTransactions : Model -> Cmd Msg
loadTransactions model =
    Http.request
        { method = "GET"
        , url = "/api/transactions"
        , expect = Http.expectJson LoadedTransactions transactionListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


transactionListDecoder : Decoder (List Transaction)
transactionListDecoder =
    list transactionDecoder


loadTxUsers : Model -> Cmd Msg
loadTxUsers model =
    Http.request
        { method = "GET"
        , url = "/api/users"
        , expect = Http.expectJson LoadedTxUsers txUsersListDecoder
        , headers = [ authHeader model.session.loginToken ]
        , body = emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


txUsersListDecoder : Decoder (List User)
txUsersListDecoder =
    list userDecoder
