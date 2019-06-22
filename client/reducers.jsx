import {
    FETCH_ERROR,
    FETCHING,
    LOGOUT,
    USER_LOGGED_IN,
    CONCEPT_ADDED,
    CONCEPTS_FETCHED
} from "#app/actions";
import PropTypes from 'prop-types';

export const stateTypes = {
    isFetching: PropTypes.number,
    loginToken: PropTypes.string,
    lastUpdated: PropTypes.number,
    emailConfirmed: PropTypes.bool,
    concepts: PropTypes.array,
    nominatim: PropTypes.array,
    photos: PropTypes.array,
    error: PropTypes.string,
};

export const initialState = {
    isFetching: 0,
    loginToken: '',
    lastUpdated: 0,
    emailConfirmed: false,
    concepts: [],
    nominatim: [],
    photos: [],
    error: '',
};

export default function reducers(state = initialState, action) {
    switch (action.type) {
        case FETCHING:
            return Object.assign({}, state, {
                isFetching: action.isFetching ? state.isFetching + 1 : state.isFetching - 1
            });
        case USER_LOGGED_IN: {
            localStorage.setItem("token", action.loginToken);
            localStorage.setItem("expire", action.loginExpire);
            return Object.assign({}, state, {
                email: action.email,
                loginExpire: action.loginExpire,
                loginToken: action.loginToken
            });
        }
        case LOGOUT: {
            localStorage.removeItem("email");
            localStorage.removeItem("token");
            localStorage.removeItem("expire");
            return Object.assign({}, state, {
                email: '',
                loginToken: ''
            });
        }
        case FETCH_ERROR:
            return Object.assign({}, state, {
                error: action.error
            });
        case CONCEPT_ADDED:
            return Object.assign({}, state, {
                concepts: action.concepts
            });
        case CONCEPTS_FETCHED:
            return Object.assign({}, state, {
                concepts: action.concepts
            });

        default:
            return state;
    }
}
