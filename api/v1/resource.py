from flask import Blueprint, jsonify, request
from api.common.parser import parseBoltRecords
from api.common.query import (queryMatchNode, queryGetNode,
                              buildNodeFilterEqual, queryResourceDependencies)
from api.settings.db import get_neo4j_db
from api.settings.auth import auth
from api.common.utils import docstring_parameter
from api.app import app

resource = Blueprint('resource', __name__)


@resource.route('/resources', methods=['GET'])
@auth.login_required
@docstring_parameter(app.config["SWAGGER_ROOT"])
def index():
    """
        Get a list of resources

        swagger_from_file: {0}/v1/swagger/resources_index.yml
    """
    filters = ""
    if request.args:
        filters = buildNodeFilterEqual(request.args.items())
    with get_neo4j_db() as session:
        nodes = parseBoltRecords(session.write_transaction(queryMatchNode,
                                                           "Resource",
                                                           filters))
        return jsonify({"data": nodes}), 200


@resource.route('/resources/<int:id>', methods=['GET'])
@auth.login_required
@docstring_parameter(app.config["SWAGGER_ROOT"])
def show(id):
    """
        Get a specified resource

        swagger_from_file: {0}/v1/swagger/resources_show.yml
    """
    with get_neo4j_db() as session:
        nodes = parseBoltRecords(session.write_transaction(queryGetNode,
                                                           "Resource",
                                                           id))
        if not nodes:
            return jsonify({"data": []}), 200
        return jsonify({"data": nodes[0]}), 200


@resource.route('/resources/<int:id>/depends', methods=['GET'])
@auth.login_required
@docstring_parameter(app.config["SWAGGER_ROOT"])
def deps(id):
    """
        Get dependecies resources ids from a specified resource

        swagger_from_file: {0}/v1/swagger/resources_deps.yml
    """
    with get_neo4j_db() as session:
        nodes = parseBoltRecords(session.write_transaction(queryGetNode,
                                                           "Resource",
                                                           id))[0]
        lista = session.write_transaction(queryResourceDependencies, id)
        nodes["depends"] = [x["(id(r))"] for x in lista.data()]
        return jsonify({"data": nodes}), 200
