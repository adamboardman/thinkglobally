import 'whatwg-fetch';

export const FETCHING = 'FETCHING';

export function fetching(fetching) {
    return {
        type: FETCHING,
        isFetching: fetching
    };
}

export const FETCH_ERROR = 'FETCH_ERROR';

export function fetchError(error) {
    return {
        type: FETCH_ERROR,
        error: error
    };
}

export const USER_LOGGED_IN = 'USER_LOGGED_IN';

export function userLogin(token, expire) {
    return {
        type: USER_LOGGED_IN,
        loginExpire: expire,
        loginToken: token
    };
}

export function userLoggedIn(token, expire) {
    return (dispatch) => {
        dispatch(userLogin(token, expire));
    };
}

export const LOGOUT = 'LOGOUT';

export function userLogout() {
    return {
        type: LOGOUT
    };
}

export function login(data) {
    return (dispatch) => {
        dispatch(fetching(true));
        dispatch(fetchError(''));

        fetch('/auth/login', {method: 'POST', body: data})
            .then(
                (response) => {
                    if (!response.ok) {
                        throw Error(response.statusText);
                    }
                    return response.json();
                })
            .then((json) => {
                localStorage.setItem("token", json.token);
                localStorage.setItem("expire", json.expire);
                dispatch(userLoggedIn(json.token, json.expire));
                dispatch(fetching(false));
            })
            .catch((err) => {
                dispatch(fetchError(err));
                dispatch(fetching(false));
            });

    };
}

export function logout() {
    return (dispatch) => {
        dispatch(userLogout());
    };
}

export function readLocalStorageForTokens() {
    return (dispatch) => {
        var token = localStorage.getItem("token");
        var expire = localStorage.getItem("expire");
        dispatch(userLoggedIn(token, expire));
    };
}

export function fetchConcepts(header) {
    return (dispatch) => {
        dispatch(fetching(true));

        fetch('/api/concepts', {method: 'GET', headers: header})
            .then(
                (response) => {
                    if (response.status === 401) {
                        dispatch(logout());
                        throw Error(response.statusText);
                    } else if (!response.ok) {
                        throw Error(response.statusText);
                    }
                    return response.json();
                })
            .then((json) => {
                dispatch(conceptsFetched(json));
                dispatch(fetching(false));
            })
            .catch(() => {
                dispatch(fetchError());
                dispatch(fetching(false));
            });
    };
}

export const CONCEPTS_FETCHED = 'CONCEPTS_FETCHED';

export function conceptsFetched(json) {
    return {
        type: CONCEPTS_FETCHED,
        concepts: json
    };
}

export function clearConcept() {
    return (dispatch) => {
        dispatch(conceptLoaded(null));
    };
}

export const CONCEPT_LOADED = 'CONCEPT_LOADED';

export function conceptLoaded(json) {
    return {
        type: CONCEPT_LOADED,
        concept: json
    };
}

export function loadConcept(id, header) {
    return (dispatch) => {
        dispatch(fetching(true));

        fetch('/api/concepts/' + id, {method: 'GET', headers: header})
            .then(
                (response) => {
                    dispatch(conceptLoaded(undefined));
                    if (response.status === 401) {
                        dispatch(logout());
                        throw Error(response.statusText);
                    } else if (!response.ok) {
                        throw Error(response.statusText);
                    }
                    return response.json();
                })
            .then((json) => {
                dispatch(conceptLoaded(json));
                dispatch(fetching(false));
            })
            .catch(() => {
                dispatch(fetchError());
                dispatch(fetching(false));
            });
    };
}

export const CONCEPT_UPDATED = 'CONCEPT_UPDATED';

export function conceptUpdated(json) {
    return {
        type: CONCEPT_UPDATED,
        conceptId: json.resourceId
    };
}

export function updateConcept(id, header, data) {
    return (dispatch) => {
        dispatch(fetching(true));

        fetch('/api/concepts/' + id, {method: 'PUT', headers: header, body: data})
            .then(
                (response) => {
                    if (!response.ok) {
                        throw Error(response.statusText);
                    }
                    return response.json();
                })
            .then((json) => {
                dispatch(conceptUpdated(json));
                dispatch(loadConcept(id, header));
                dispatch(fetching(false));
            })
            .catch((err) => {
                dispatch(addError(err));
                dispatch(fetching(false));
            });

    };
}

export function addConcept(header, data) {
    return (dispatch) => {
        dispatch(fetching(true));

        fetch('/api/concepts', {method: 'POST', headers: header, body: data})
            .then(
                (response) => {
                    if (!response.ok) {
                        throw Error(response.statusText);
                    }
                    return response.json();
                })
            .then((json) => {
                dispatch(conceptUpdated(json));
                dispatch(loadConcept(json.resourceId, header));
                dispatch(fetching(false));
            })
            .catch((err) => {
                dispatch(addError(err));
                dispatch(fetching(false));
            });

    };
}
