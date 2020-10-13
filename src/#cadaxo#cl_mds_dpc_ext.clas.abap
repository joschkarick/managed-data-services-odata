CLASS /cadaxo/cl_mds_dpc_ext DEFINITION
  PUBLIC
  INHERITING FROM /cadaxo/cl_mds_dpc
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-METHODS class_constructor.

  PROTECTED SECTION.
    METHODS datasources_get_entityset REDEFINITION.
    METHODS datasources_get_entity REDEFINITION.
    METHODS links_get_entityset REDEFINITION.
    METHODS links_get_entity REDEFINITION.
    METHODS fields_get_entityset REDEFINITION.
    METHODS fields_get_entity REDEFINITION.
    METHODS annotations_get_entityset REDEFINITION.
    METHODS annotations_get_entity REDEFINITION.
    METHODS parameters_get_entityset REDEFINITION.
    METHODS parameters_get_entity REDEFINITION.
  PRIVATE SECTION.
    CLASS-DATA: api TYPE REF TO /cadaxo/if_mds_api.
ENDCLASS.



CLASS /cadaxo/cl_mds_dpc_ext IMPLEMENTATION.

  METHOD class_constructor.
    api = /cadaxo/cl_mds_api=>get_instance( ).
  ENDMETHOD.

  METHOD datasources_get_entityset.
    DATA: object_semantic_key TYPE /cadaxo/mds_ds_semkey.
    DATA: read_depth_string TYPE string.
    DATA: read_depth TYPE i.
    DATA: rest TYPE c.

    DATA(searchstring) = cl_http_utility=>unescape_url( iv_search_string ).
    SPLIT searchstring AT '|' INTO object_semantic_key-name object_semantic_key-type read_depth_string rest.
    read_depth = read_depth_string.

    DATA(nodes) = api->get_datasources_by_semkey( i_ds_semkey  = object_semantic_key
                                                  i_read_depth = read_depth ).

    et_entityset = CORRESPONDING #( nodes MAPPING object_name = name object_type = type ).

  ENDMETHOD.


  METHOD datasources_get_entity.

    DATA converted_keys LIKE er_entity.

    DATA(navigation) = io_tech_request_context->get_navigation_path( ).
*    DATA(source_setname) = io_tech_request_context->get_source_entity_set_name( ).
*    DATA(source_typename) = io_tech_request_context->get_source_entity_type_name( ).

    IF navigation IS INITIAL.
      io_tech_request_context->get_converted_keys( IMPORTING es_key_values = converted_keys ).
    ELSE.
      DATA: field TYPE /cadaxo/cl_mds_mpc=>ts_field.
*              io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = converted_keys ).
      io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = field ).
*          io_tech_request_context->get_converted_keys( IMPORTING es_key_values = field ).

*      io_tech_request_context->get_converted_navi_target_keys( EXPORTING is_navigation_path = navigation[ 1 ]
*                                                               IMPORTING es_key_values      = converted_keys ).

      converted_keys = CORRESPONDING #( api->get_field_by_id( field-field_id ) ).
    ENDIF.

    DATA(nodes) = api->get_datasources_by_id( i_ds_id = converted_keys-ds_id i_read_depth = 0 ).

    er_entity = CORRESPONDING #( nodes[ 1 ] MAPPING object_name = name object_type = type ).

  ENDMETHOD.


  METHOD links_get_entityset.

    DATA converted_keys TYPE /cadaxo/cl_mds_mpc_ext=>ts_datasource.

    IF  it_navigation_path   IS INITIAL.
*      io_tech_request_context->get_converted_keys( IMPORTING es_key_values = converted_keys ).
    ELSE.
      io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = converted_keys ).
      IF it_navigation_path[ 1 ]-nav_prop = 'toAllLinks'.
        DATA(getall) = abap_true.
      ENDIF.
    ENDIF.

    DATA(links) = api->get_links_by_dsid( converted_keys-ds_id ).

    IF getall = abap_true.

      DATA(datasources) = api->get_datasources_by_id( i_ds_id      = links[ 1 ]-object_id1
                                                      i_read_depth = 1 ).

      DATA: alllinks LIKE links.

      LOOP AT datasources ASSIGNING FIELD-SYMBOL(<datasource>).

        APPEND LINES OF api->get_links_by_dsid( <datasource>-ds_id ) TO alllinks.
      ENDLOOP.

      SORT alllinks.
      DELETE ADJACENT DUPLICATES FROM alllinks.
      et_entityset = CORRESPONDING #( alllinks MAPPING type = relation_type ).

    ELSE.

      et_entityset = CORRESPONDING #( links MAPPING type = relation_type ).

    ENDIF.
  ENDMETHOD.


  METHOD links_get_entity.

    DATA converted_keys LIKE er_entity.

    DATA(navigation) = io_tech_request_context->get_navigation_path( ).
    DATA(source_setname) = io_tech_request_context->get_source_entity_set_name( ).
    DATA(source_typename) = io_tech_request_context->get_source_entity_type_name( ).

*    IF navigation IS INITIAL.
    io_tech_request_context->get_converted_keys( IMPORTING es_key_values = converted_keys ).
*    ELSE.
*      io_tech_request_context->get_converted_navi_target_keys( EXPORTING is_navigation_path = navigation[ 1 ]
*                                                               IMPORTING es_key_values      = converted_keys ).
*    ENDIF.

    DATA(link) = api->get_link_by_id( converted_keys-link_id ).

    er_entity = CORRESPONDING #( link MAPPING type = relation_type ).

  ENDMETHOD.


  METHOD fields_get_entityset.

    DATA converted_keys TYPE /cadaxo/cl_mds_mpc_ext=>ts_datasource.

    io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = converted_keys ).

    DATA(fields) = api->get_fields_by_dsid( i_ds_id = converted_keys-ds_id ).

    LOOP AT fields ASSIGNING FIELD-SYMBOL(<field>).
      APPEND CORRESPONDING #( <field>-api->get_as_structure( ) )  TO et_entityset.
    ENDLOOP.

  ENDMETHOD.


  METHOD fields_get_entity.

    DATA converted_keys LIKE er_entity.

    io_tech_request_context->get_converted_keys( IMPORTING es_key_values = converted_keys ).

    DATA(field) = api->get_field_by_id( converted_keys-field_id ).

    er_entity = CORRESPONDING #( field-api->get_as_structure( ) ).

  ENDMETHOD.


  METHOD annotations_get_entityset.

    CASE iv_source_name.
      WHEN 'Datasource'.
        DATA ds_keys TYPE /cadaxo/cl_mds_mpc_ext=>ts_datasource.
        io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = ds_keys ).
        DATA(annotations) = api->get_annotations_by_dsid( ds_keys-ds_id ).

      WHEN 'Field'.
        DATA field_keys TYPE /cadaxo/cl_mds_mpc_ext=>ts_field.
        io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = field_keys ).
        annotations = api->get_annotations_by_fieldid( field_keys-field_id ).

    ENDCASE.

    et_entityset = CORRESPONDING #( annotations MAPPING annotation_name = annotation ).

  ENDMETHOD.


  METHOD annotations_get_entity.

    DATA converted_keys LIKE er_entity.

    io_tech_request_context->get_converted_keys( IMPORTING es_key_values = converted_keys ).

    DATA(annotation) = api->get_annotation_by_id( converted_keys-annotation_id ).

    er_entity = CORRESPONDING #( annotation MAPPING annotation_name = annotation ).

  ENDMETHOD.


  METHOD parameters_get_entityset.

  ENDMETHOD.


  METHOD parameters_get_entity.

  ENDMETHOD.

ENDCLASS.
