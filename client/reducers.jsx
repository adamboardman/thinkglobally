import {
    CONCEPT_LOADED,
    CONCEPT_TAG_ADDED,
    CONCEPT_TAG_DELETED,
    CONCEPT_TAGS_LOADED,
    CONCEPTS_FETCHED,
    FETCH_ERROR,
    FETCHING,
    LOGOUT,
    USER_LOGGED_IN,
} from "#app/actions";
import PropTypes from 'prop-types';

export const stateTypes = {
    isFetching: PropTypes.number,
    loginToken: PropTypes.string,
    lastUpdated: PropTypes.number,
    emailConfirmed: PropTypes.bool,
    concepts: PropTypes.array,
    photos: PropTypes.array,
    error: PropTypes.string,
};

export const initialState = {
    isFetching: 0,
    loginToken: '',
    lastUpdated: 0,
    emailConfirmed: false,
    concepts: [],
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
        case CONCEPT_LOADED:
            return Object.assign({}, state, {
                concept: action.concept
            });
        case CONCEPTS_FETCHED:
            return Object.assign({}, state, {
                concepts: action.concepts
            });
        case CONCEPT_TAG_ADDED: {
            let newTag = {};
            newTag.ID = action.tagId;
            newTag.Tag = action.tagTag;
            newTag.ConceptId = action.tagConceptId;
            let newConcept = state.concept;
            if (newConcept.Tags != null) {
                newConcept.Tags.push(newTag);
            } else {
                newConcept.Tags = [newTag];
            }
            let newTags = state.tags;
            if (newTags === undefined) {
                newTags = [];
            }
            newTags.push(newTag);
            return Object.assign({}, state, {
                conceptTags: newTags,
                concept: newConcept,
            });
        }
        case CONCEPT_TAG_DELETED: {
            let newConcept = state.concept;
            if (newConcept.Tags != null) {
                let index = -1;
                for (let i = 0; i < newConcept.Tags.length; i++) {
                    if (action.tagId === newConcept.Tags[i].ID) {
                        index = i;
                    }
                }
                if (index > -1) {
                    newConcept.Tags.splice(index, 1);
                }
            }
            let newTags = state.tags;
            if (newTags != null) {
                let index = -1;
                for (let i = 0; i < newTags.length; i++) {
                    if (action.tagId === newTags[i].ID) {
                        index = i;
                    }
                }
                if (index > -1) {
                    newTags.splice(index, 1);
                }
            }
            return Object.assign({}, state, {
                conceptTags: newTags,
                concept: newConcept,
            });
        }
        case CONCEPT_TAGS_LOADED: {
            let newConcept = state.concept;
            if (newConcept.ID == action.conceptTagsConceptId) {
                newConcept.Tags = action.conceptTagsConceptTags;
            }
            return Object.assign({}, state, {
                concept: newConcept,
            });
        }
        default:
            return state;
    }
}
