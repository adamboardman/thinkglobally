import React from "react";
import {fetchConcept, logout} from "#app/actions";
import {connect} from 'react-redux';
import PropTypes from 'prop-types';
import ConceptContent from "./conceptcontent";

class Concept extends React.Component {

    componentDidMount() {
        const headers = new Headers({"Authorization": "Bearer " + this.props.loginToken});
        var tag = this.props.match.params.tag;
        if (tag === undefined) {
            tag = "index";
        }
        this.props.fetchConcept(tag,headers);
    }

    render() {
        const {loginToken, concept, displayableTagsList} = this.props;
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
