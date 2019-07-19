module Tests exposing (decodeConcept, decodeLogin, decodeRegister, decodeUser, failsWithMissingJson, success)

import Expect exposing (Expectation)
import Json.Decode
import Login exposing (loginDecoder)
import Register exposing (registerDecoder)
import Test exposing (..)
import Types exposing (conceptDecoder, userDecoder)


decodeLogin : Test
decodeLogin =
    test "decode login response json" <|
        \() ->
            let
                input =
                    """
                    {"status":200,"expire":"2019-07-24T15:21:44+01:00","token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJjb25maXJtZWQiOnRydWUsImVtYWlsIjoidGVzdDlAZXhhbXBsZS5jb20iLCJleHAiOjE1NjM5NzgxMDQsImlkIjoyNzgsIm9yaWdfaWF0IjoxNTYzMzczMzA0fQ.9U1L7SKH4ISwwNGwQ9giNCC2q5UMXT0Tw2WQ5f4itVU"}
                    """

                decodedOutput =
                    Json.Decode.decodeString
                        loginDecoder
                        input
            in
            Expect.equal decodedOutput
                (Ok
                    { loginExpire = "2019-07-24T15:21:44+01:00"
                    , loginToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJjb25maXJtZWQiOnRydWUsImVtYWlsIjoidGVzdDlAZXhhbXBsZS5jb20iLCJleHAiOjE1NjM5NzgxMDQsImlkIjoyNzgsIm9yaWdfaWF0IjoxNTYzMzczMzA0fQ.9U1L7SKH4ISwwNGwQ9giNCC2q5UMXT0Tw2WQ5f4itVU"
                    }
                )


success : Result a b -> Bool
success result =
    case result of
        Ok _ ->
            True

        Err _ ->
            False


failsWithMissingJson : Test
failsWithMissingJson =
    test "fail on wrong login json response" <|
        \() ->
            let
                input =
                    """
                        {"expire":1,"token":2}
                        """

                decodedOutput =
                    Json.Decode.decodeString
                        loginDecoder
                        input
            in
            Expect.equal (success decodedOutput) False


decodeRegister : Test
decodeRegister =
    test "decode register response json" <|
        \() ->
            let
                input =
                    """
                    {"message":"User registered successfully","resourceId":315,"status":200}
                    """

                decodedOutput =
                    Json.Decode.decodeString
                        registerDecoder
                        input
            in
            Expect.equal decodedOutput
                (Ok
                    { status = 200
                    , resourceId = 315
                    }
                )


decodeUser : Test
decodeUser =
    test "decode user response json" <|
        \() ->
            let
                input =
                    """
                    {"ID":9,"CreatedAt":"2019-07-11T14:50:37.443151+01:00","UpdatedAt":"2019-07-13T21:02:21.214296+01:00","DeletedAt":null,"FirstName":"FNS","MidNames":"MN","LastName":"LN","Location":"LOC","PhotoID":0,"Email":"EAD","Mobile":"MOB","Confirmed":true,"Permissions":1}
                    """

                decodedOutput =
                    Json.Decode.decodeString
                        userDecoder
                        input
            in
            Expect.equal decodedOutput
                (Ok
                    { id = 9
                    , firstName = "FNS"
                    , midNames = "MN"
                    , lastName = "LN"
                    , location = "LOC"
                    , email = "EAD"
                    , mobile = "MOB"
                    , permissions = 1
                    }
                )


decodeConcept : Test
decodeConcept =
    test "decode concept response json" <|
        \() ->
            let
                input =
                    """
                   {"ID":21,"CreatedAt":"2019-07-12T11:27:37.338297+01:00","UpdatedAt":"2019-07-12T12:23:50.763285+01:00","DeletedAt":null,"Name":"Account Recovery","Summary":"lost secret keys","Full":"With TG's"}
                    """

                decodedOutput =
                    Json.Decode.decodeString
                        conceptDecoder
                        input
            in
            Expect.equal decodedOutput
                (Ok
                    { id = 21
                    , name = "Account Recovery"
                    , summary = "lost secret keys"
                    , full = "With TG's"
                    , tags = []
                    }
                )
