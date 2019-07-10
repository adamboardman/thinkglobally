import React from "react";
import {fetchConcept, logout} from "#app/actions";
import {connect} from 'react-redux';
import PropTypes from 'prop-types';
import ConceptContent from "./conceptcontent";

class Concept extends React.Component {

    componentDidMount() {
    }

    render() {
        const {isFetching, loginToken, concept, displayableTagsList} = this.props;
        let tag = this.props.match.params.tag;
        if (tag === undefined) {
            tag = "index";
        }
        if (!isFetching && (!concept || tag !== concept.Tags[0].Tag)) {
            const headers = new Headers({"Authorization": "Bearer " + loginToken});
            this.props.fetchConcept(tag, headers);
        }
        return (
            <div className="card-deck">
                <ConceptContent key={concept ? concept.ID : 0} loginToken={loginToken} concept={concept} displayableTagsList={displayableTagsList}/>
            </div>
        );
    }
}

Concept.propTypes = {
    fetchConcept: PropTypes.func.isRequired,
    logout: PropTypes.func.isRequired,
    isFetching: PropTypes.number,
    loginToken: PropTypes.string,
    lastUpdated: PropTypes.number,
    concept: PropTypes.object,
    displayableTagsList: PropTypes.array,
};

const mapConceptsStateToProps = (state) => {
    return {
        isFetching: state.isFetching,
        loginToken: state.loginToken,
        lastUpdated: state.lastUpdated,
        concept: state.concept,
        displayableTagsList: state.displayableTagsList
    };
};

const mapConceptsDispatchToProps = (dispatch) => {
    return {
        fetchConcept: (userInfo) => dispatch(fetchConcept(userInfo)),
        logout: () => dispatch(logout())
    };
};

export default connect(mapConceptsStateToProps, mapConceptsDispatchToProps)(Concept);
