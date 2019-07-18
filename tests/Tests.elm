module Tests exposing (decodeLogin, decodeRegister, failsWithMissingJson, success)

import Expect exposing (Expectation)
import Json.Decode
import Login exposing (loginDecoder)
import Register exposing (registerDecoder)
import Test exposing (..)


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
