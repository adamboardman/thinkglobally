import React from "react";
import {fetchConcepts, logout} from "#app/actions";
import {connect} from 'react-redux';
import PropTypes from 'prop-types';
import ConceptContent from "./conceptcontent";

class ConceptList extends React.Component {

    componentDidMount() {
        const headers = new Headers({"Authorization": "Bearer " + this.props.loginToken});
        this.props.fetchConcepts(headers);
    }

    render() {
        const {loginToken, concepts} = this.props;
        return (
            <div className="card-deck">
                {concepts ? concepts.map((concept) => {
                    return (<ConceptContent key={concept.ID} loginToken={loginToken} concept={concept}/>);
                }) : (<div></div>)}
            </div>
        );
    }
}

ConceptList.propTypes = {
    fetchConcepts: PropTypes.func.isRequired,
    logout: PropTypes.func.isRequired,
    isFetching: PropTypes.number,
    loginToken: PropTypes.string,
    lastUpdated: PropTypes.number,
    concepts: PropTypes.array
};

const mapConceptsStateToProps = (state) => {
    return {
        isFetching: state.isFetching,
        loginToken: state.loginToken,
        lastUpdated: state.lastUpdated,
        concepts: state.concepts
    };
};

const mapConceptsDispatchToProps = (dispatch) => {
    return {
        fetchConcepts: (userInfo) => dispatch(fetchConcepts(userInfo)),
        logout: () => dispatch(logout())
    };
};

export default connect(mapConceptsStateToProps, mapConceptsDispatchToProps)(ConceptList);
