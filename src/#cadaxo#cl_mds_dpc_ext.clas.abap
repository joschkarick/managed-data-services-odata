class /CADAXO/CL_MDS_DPC_EXT definition
  public
  inheriting from /CADAXO/CL_MDS_DPC
  create public .

public section.

  class-methods CLASS_CONSTRUCTOR .
protected section.

  methods ANNOTATIONS_GET_ENTITY
    redefinition .
  methods ANNOTATIONS_GET_ENTITYSET
    redefinition .
  methods DATASOURCES_GET_ENTITY
    redefinition .
  methods DATASOURCES_GET_ENTITYSET
    redefinition .
  methods FIELDS_GET_ENTITY
    redefinition .
  methods FIELDS_GET_ENTITYSET
    redefinition .
  methods LEGENDCUSTS_GET_ENTITYSET
    redefinition .
  methods LINKS_GET_ENTITY
    redefinition .
  methods LINKS_GET_ENTITYSET
    redefinition .
  methods PARAMETERS_GET_ENTITY
    redefinition .
  methods PARAMETERS_GET_ENTITYSET
    redefinition .
  methods PROPERTIES_GET_ENTITY
    redefinition .
  methods PROPERTIES_GET_ENTITYSET
    redefinition .
  methods ROOTDATASOURCES_GET_ENTITYSET
    redefinition .
  methods ROOTDATASOURCES_GET_ENTITY
    redefinition .
  PRIVATE SECTION.
    CONSTANTS version_string TYPE string VALUE 'Backend: Odata 0.9-14af9d5 API 0.9-f9c93fe' ##NO_TEXT.
    CLASS-DATA: api TYPE REF TO /cadaxo/if_mds_api.
    METHODS parse_fieldname_filter IMPORTING io_tech_request_context TYPE REF TO /iwbep/if_mgw_req_entityset
                                   RETURNING VALUE(r_filter)         TYPE /cadaxo/mds_field_search
                                   RAISING   /iwbep/cx_mgw_busi_exception
                                             /iwbep/cx_mgw_tech_exception.
ENDCLASS.



CLASS /CADAXO/CL_MDS_DPC_EXT IMPLEMENTATION.


  METHOD annotations_get_entity.

    DATA converted_keys LIKE er_entity.

    io_tech_request_context->get_converted_keys( IMPORTING es_key_values = converted_keys ).

    DATA(annotation) = api->get_annotation_by_id( converted_keys-annotation_id ).

    er_entity = CORRESPONDING #( annotation MAPPING annotation_name = annotation ).

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

    DELETE annotations WHERE value IS INITIAL.

    et_entityset = CORRESPONDING #( annotations MAPPING annotation_name = annotation ).

  ENDMETHOD.


  METHOD class_constructor.
    api = /cadaxo/cl_mds_api=>get_instance( ).
  ENDMETHOD.


  METHOD datasources_get_entity.

    DATA converted_keys LIKE er_entity.

    DATA(navigation) = io_tech_request_context->get_navigation_path( ).
*    DATA(source_setname) = io_tech_request_context->get_source_entity_set_name( ).
*    DATA(source_typename) = io_tech_request_context->get_source_entity_type_name( ).

    IF navigation IS INITIAL.
      io_tech_request_context->get_converted_keys( IMPORTING es_key_values = converted_keys ).
    ELSE.
      DATA: field_sm TYPE /cadaxo/cl_mds_mpc=>ts_field.
      DATA: link_sm  TYPE /cadaxo/cl_mds_mpc=>ts_link.
      DATA: parameter_sm  TYPE /cadaxo/cl_mds_mpc=>ts_parameter.
      DATA: property_sm  TYPE /cadaxo/cl_mds_mpc=>ts_property.
      CASE navigation[ 1 ]-source_entity_type.
        WHEN 'Field'.
          io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = field_sm ).
* io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = converted_keys ).
* io_tech_request_context->get_converted_keys( IMPORTING es_key_values = field ).
* io_tech_request_context->get_converted_navi_target_keys( EXPORTING is_navigation_path = navigation[ 1 ]
*                                                          IMPORTING es_key_values      = converted_keys ).
          converted_keys = CORRESPONDING #( api->get_field_by_id( field_sm-field_id ) ).

        WHEN 'Link'.

          io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = link_sm ).
          CASE navigation[ 1 ]-nav_prop.
            WHEN 'TODATASOURCE1'.
              converted_keys = CORRESPONDING #( api->get_link_by_id( link_sm-link_id ) MAPPING ds_id = object_id1 ).
            WHEN 'TODATASOURCE2'.
              converted_keys = CORRESPONDING #( api->get_link_by_id( link_sm-link_id ) MAPPING ds_id = object_id2 ).
          ENDCASE.

        WHEN 'Parameter'.

          io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = parameter_sm ).
          converted_keys = CORRESPONDING #( api->get_parameter_by_id( parameter_sm-parameter_id ) ).

        WHEN 'Property'.

          io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = property_sm ).
          converted_keys = CORRESPONDING #( api->get_property_by_id( property_sm-property_id ) ).

      ENDCASE.
    ENDIF.

    DATA(nodes) = api->get_datasources_by_id( i_ds_id = converted_keys-ds_id ).
    DATA(nodeapi) = nodes[ 1 ]-api.

    er_entity = CORRESPONDING #( nodes[ 1 ] MAPPING object_name = name object_type = type ).
    er_entity-link = nodeapi->get_action_links(  ).

    er_entity-managed-version = version_string.
  ENDMETHOD.


  METHOD datasources_get_entityset.
    DATA: object_semantic_key TYPE /cadaxo/mds_ds_semkey.
    DATA: rest TYPE c.

    DATA(searchstring) = cl_http_utility=>unescape_url( iv_search_string ).
    SPLIT searchstring AT '|' INTO object_semantic_key-name object_semantic_key-type rest.

    DATA(search_4_field) = parse_fieldname_filter( io_tech_request_context ).
*
*    DATA(filter) = io_tech_request_context->get_filter( ).
*    DATA(filter_so) = filter->get_filter_select_options( ).

    DATA converted_keys TYPE /cadaxo/cl_mds_mpc_ext=>ts_datasource.

    "If coming from /toChildDatasources
    IF it_navigation_path IS NOT INITIAL.
      io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = converted_keys ).
      IF it_navigation_path[ 1 ]-nav_prop = 'toChildDatasources'.
        DATA(getChildDatasources) = abap_true.
      ENDIF.
    ENDIF.



    IF object_semantic_key IS NOT INITIAL.

      TRY.
          DATA(dss) = api->get_datasources_by_semkey( i_ds_semkey         = object_semantic_key
                                                      i_filter_datasource = search_4_field-search_object_name
                                                      i_filter_fieldname  = search_4_field-search_field_name ).

      CATCH /cadaxo/cx_mds_id INTO DATA(exception).
        RAISE EXCEPTION TYPE  /iwbep/cx_mgw_busi_exception EXPORTING textid = exception->if_t100_message~t100key.
      ENDTRY.

    ELSEIF converted_keys-ds_id IS NOT INITIAL.
 "  coming from /toChildDatasources
 "  TODO build filter - in DSS remain all converted_keys-object_type only
      TRY.
        dss = api->get_datasources_by_id( i_ds_id             = converted_keys-ds_id ).
      CATCH /cadaxo/cx_mds_id INTO exception.
        RAISE EXCEPTION TYPE  /iwbep/cx_mgw_busi_exception EXPORTING textid = exception->if_t100_message~t100key.
      ENDTRY.
    ELSE.

    ENDIF.

    LOOP AT dss ASSIGNING FIELD-SYMBOL(<ds>).

      APPEND CORRESPONDING #( <ds>-api->get_datasource( ) MAPPING object_name = name object_type = type ) TO et_entityset ASSIGNING FIELD-SYMBOL(<entity>).

      <entity>-link = CORRESPONDING #( <ds>-api->get_action_links( ) ).
      <entity>-field_search = <ds>-field_search.

      <entity>-object_state = SWITCH #( <ds>-role WHEN /cadaxo/if_mds_api=>ds_role-main THEN 100
                                                WHEN /cadaxo/if_mds_api=>ds_role-parent THEN 110
                                                WHEN /cadaxo/if_mds_api=>ds_role-child THEN 120 ).
      IF search_4_field IS NOT INITIAL AND <ds>-field_search IS INITIAL.
        IF search_4_field-action_name <> 'ExpandObject'.
          <entity>-object_state = <entity>-object_state + 100.
        ENDIF.
      ENDIF.

      <entity>-managed-version = version_string.
    ENDLOOP.

    IF search_4_field IS NOT INITIAL AND search_4_field-action_name = 'GetFieldSource'.
        DELETE et_entityset WHERE object_state > 200 OR object_state = 120.
    ELSEIF search_4_field IS NOT INITIAL AND search_4_field-action_name = 'GetFieldSourceAll'.
        DELETE et_entityset WHERE object_state = 220 OR object_state = 120.
    ENDIF.


    IF search_4_field IS NOT INITIAL AND search_4_field-action_name = 'GetFieldTarget'.
      DELETE et_entityset WHERE object_state > 200 OR object_state = 110.
    ELSEIF search_4_field IS NOT INITIAL AND search_4_field-action_name = 'GetFieldTargetAll'.
      DELETE et_entityset WHERE object_state = 210 OR object_state = 110.
    ENDIF.

    IF search_4_field-action_name = 'ExpandObject'.
    "TODO - apply some filters to et_entityset
    ENDIF.

  ENDMETHOD.


  METHOD fields_get_entity.

    DATA converted_keys LIKE er_entity.

    io_tech_request_context->get_converted_keys( IMPORTING es_key_values = converted_keys ).

    DATA(field) = api->get_field_by_id( converted_keys-field_id ).

    er_entity = CORRESPONDING #( field-api->get_as_structure( ) MAPPING length = length_string ).

  ENDMETHOD.


  METHOD fields_get_entityset.

    DATA converted_keys TYPE /cadaxo/cl_mds_mpc_ext=>ts_datasource.

    DATA(filter) = io_tech_request_context->get_filter( ).
    DATA(filter_so) = filter->get_filter_select_options( ).

    io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = converted_keys ).

    DATA(fields) = api->get_fields_by_dsid( i_ds_id = converted_keys-ds_id ).

    LOOP AT fields ASSIGNING FIELD-SYMBOL(<field>).
      APPEND CORRESPONDING #( <field>-api->get_as_structure( ) MAPPING length = length_string )  TO et_entityset.
    ENDLOOP.

  ENDMETHOD.


  METHOD legendcusts_get_entityset.
    et_entityset = VALUE #( ( legend_id = '1'  status_key = 'TABL'                 color_1 = 'darkblue'    color_2 = 'blue'  description = 'Table')
                            ( legend_id = '2'  status_key = 'DDLS'                 color_1 = 'darkgreen'   color_2 = 'green' description = 'CDS View')
                            ( legend_id = '3'  status_key = 'DDLX'                 color_1 = 'lime'        color_2 = 'green' description = 'CDS Extension' )
                            ( legend_id = '12' status_key = 'YDLS'                 color_1 = 'teal'        color_2 = 'teal'  description = 'CDS View Extension' )
                            ( legend_id = '13' status_key = 'YABL'                 color_1 = 'navy'        color_2 = 'navy'  description = 'SQL View' )

                            ( legend_id = '101' status_key = 'XXFILTERED_TABL'     color_1 = 'grey'        color_2 = 'grey'  description = 'Table - filtered')
                            ( legend_id = '102' status_key = 'XXFILTERED_DDLS'     color_1 = 'grey'        color_2 = 'grey'  description = 'CDS View - filtered')
                            ( legend_id = '103' status_key = 'XXFILTERED_DDLX'     color_1 = 'grey'        color_2 = 'grey'  description = 'CDS Extension - filtered' )
                            ( legend_id = '112' status_key = 'XXFILTERED_YDLS'     color_1 = 'grey'        color_2 = 'grey'  description = 'CDS View Extension - filtered' )
                            ( legend_id = '113' status_key = 'XXFILTERED_YABL'     color_1 = 'grey'        color_2 = 'grey'  description = 'SQL View - filtered' )

                            ( legend_id = '4'  status_key = 'BASE'                 color_1 = 'blue'        color_2 = 'silver'    description = 'As select from' )
                            ( legend_id = '5'  status_key = 'ASSOCIATION'          color_1 = 'green'       color_2 = 'fuchsia'   description = 'Association' )
                            ( legend_id = '6'  status_key = 'EXTERNAL_ASSOCIATION' color_1 = 'darkgreen'   color_2 = 'yellow'    description = 'Ext. Association' )
                            ( legend_id = '7'  status_key = 'ISUSED'               color_1 = 'orange'      color_2 = 'aqua'      description = 'Is used in' )
                            ( legend_id = '8'  status_key = 'SQLVIEW'              color_1 = 'darkblue'    color_2 = 'lime'      description = 'Has SQL View' )
                            ( legend_id = '9'  status_key = 'METADATAEXTENSION'    color_1 = 'lime'        color_2 = 'teal'      description = 'Has Metadata Extension' )
                            ( legend_id = '10' status_key = 'ENHANCEMENT'          color_1 = 'darkmagenta' color_2 = 'olive'     description = 'Enhances' )
                            ( legend_id = '11' status_key = 'DISABLED'             color_1 = 'grey'        color_2 = 'grey'      description = 'Disabled' ) ).
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

      DATA(datasources) = api->get_datasources_by_id( i_ds_id      = links[ 1 ]-object_id1 ).

      DATA: alllinks LIKE links.
      DATA: rg_used_ds TYPE RANGE OF /cadaxo/mds_ds_id.
      LOOP AT datasources ASSIGNING FIELD-SYMBOL(<datasource>).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <datasource>-ds_id ) TO rg_used_ds.
        APPEND LINES OF api->get_links_by_dsid( <datasource>-ds_id ) TO alllinks.
      ENDLOOP.

      DELETE alllinks WHERE object_id1 NOT IN rg_used_ds.
      DELETE alllinks WHERE object_id2 NOT IN rg_used_ds.

      SORT alllinks.
      DELETE ADJACENT DUPLICATES FROM alllinks.

      LOOP AT alllinks ASSIGNING FIELD-SYMBOL(<alllink>) WHERE relation_type <> 'ISUSED'.
        DATA(to) = <alllink>-object_id2.
        <alllink>-object_id2 = <alllink>-object_id1.
        <alllink>-object_id1 = to.
      ENDLOOP.
      et_entityset = CORRESPONDING #( alllinks MAPPING type = relation_type ).

    ELSE.

      et_entityset = CORRESPONDING #( links MAPPING type = relation_type ).

    ENDIF.
  ENDMETHOD.


  METHOD parameters_get_entity.

    DATA converted_keys LIKE er_entity.

    io_tech_request_context->get_converted_keys( IMPORTING es_key_values = converted_keys ).

    DATA(parameter) = api->get_parameter_by_id( converted_keys-parameter_id ).

    er_entity = CORRESPONDING #( parameter ).

  ENDMETHOD.


  METHOD parameters_get_entityset.

    DATA converted_keys TYPE /cadaxo/cl_mds_mpc_ext=>ts_datasource.

    io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = converted_keys ).

    DATA(parameters) = api->get_parameters_by_dsid( i_ds_id = converted_keys-ds_id ).

    LOOP AT parameters ASSIGNING FIELD-SYMBOL(<parameter>).
      APPEND CORRESPONDING #( <parameter> )  TO et_entityset.
    ENDLOOP.

  ENDMETHOD.


  METHOD parse_fieldname_filter.

    CONSTANTS: BEGIN OF filter_node_kind,
                 unary    TYPE c LENGTH 1 VALUE 'U',
                 binary   TYPE c LENGTH 1 VALUE 'B',
                 literal  TYPE c LENGTH 1 VALUE 'C',
                 function TYPE c LENGTH 1 VALUE 'F',
                 member   TYPE c LENGTH 1 VALUE 'M',
                 property TYPE c LENGTH 1 VALUE 'P',
               END OF filter_node_kind.

    DATA: filter_tree             TYPE REF TO /iwbep/if_mgw_expr_node.
    DATA: left_node               TYPE REF TO /iwbep/if_mgw_expr_node.
    DATA: right_node              TYPE REF TO /iwbep/if_mgw_expr_node.
    DATA: binary                  TYPE REF TO /iwbep/if_mgw_expr_binary.
    DATA: function                TYPE REF TO /iwbep/if_mgw_expr_function.
    DATA: property                TYPE REF TO /iwbep/if_mgw_expr_property.
    DATA: literal                 TYPE REF TO /iwbep/if_mgw_expr_literal.
    DATA: member                  TYPE REF TO /iwbep/if_mgw_expr_member.
    DATA: function_parameters     TYPE /iwbep/if_mgw_expr_function=>parameter_t.
    DATA: operator_name           TYPE string.
    DATA: function_name           TYPE string.
    DATA: property_name           TYPE string.
    DATA: supported_filter_string TYPE string.
    DATA: filter_error            TYPE string.
    DATA: wrong_filter            TYPE abap_bool.
    DATA: filter_select_options   TYPE /iwbep/t_mgw_select_option.



    wrong_filter = abap_false.

    supported_filter_string = |Only the following filterstring is supported: FieldSearch/SearchFieldName eq '<Fieldname>'|.

    filter_select_options = io_tech_request_context->get_filter( )->get_filter_select_options( ).

    IF filter_select_options IS NOT INITIAL.

      TRY.
          r_filter-search_object_name = filter_select_options[ property = 'FIELD_SEARCH-SEARCH_OBJECT_NAME' ]-select_options[ sign = 'I' option = 'EQ'  ]-low.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.
      TRY.
          r_filter-search_field_name = filter_select_options[ property = 'FIELD_SEARCH-SEARCH_FIELD_NAME' ]-select_options[ sign = 'I' option = 'EQ'  ]-low.
        CATCH cx_sy_itab_line_not_found.
          wrong_filter = abap_true.
      ENDTRY.

      TRY.
          r_filter-action_name = filter_select_options[ property = 'FIELD_SEARCH-ACTION_NAME' ]-select_options[ sign = 'I' option = 'EQ'  ]-low.
        CATCH cx_sy_itab_line_not_found.
          wrong_filter = abap_true.
      ENDTRY.

    ELSE.

      filter_tree = io_tech_request_context->get_filter_expression_tree( ).

      IF filter_tree IS BOUND.
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            textid            = /iwbep/cx_mgw_busi_exception=>business_error_unlimited
            message_unlimited = filter_error && supported_filter_string.

        IF filter_tree->kind = filter_node_kind-binary.

          filter_tree->prepare_converted_values( ).
          binary ?= filter_tree.
          operator_name = binary->operator.
          left_node  = binary->left_operand.
          right_node = binary->right_operand.

          IF left_node IS BOUND.
            IF left_node->kind = filter_node_kind-function.

              function ?= left_node.
              function_name = function->function.
              IF function_name <> 'substringof'.
                filter_error = 'Only substringof is supported. '.
                wrong_filter = abap_true.
              ENDIF.

              function_parameters = function->parameters.

              IF function_parameters IS NOT INITIAL.

                DATA(param1) = function_parameters[ 1 ].
                IF param1->kind = filter_node_kind-literal.
                  literal ?= param1.
                  r_filter-search_field_name = literal->literal_converted.
                ELSE.
                  wrong_filter = abap_true.
                ENDIF.
                DATA(param2) = function_parameters[ 2 ].
                IF param2->kind = filter_node_kind-property.
                  property ?= param2.
                  property_name = property->property_name.
                ELSE.
                  wrong_filter = abap_true.
                ENDIF.

                IF property_name = 'FIELD_NAME'.
*
*                  ls_supplier_name-sign  = 'I'.
*                  ls_supplier_name-option  ='CP'.
*                  ls_supplier_name-low  = '*' && r_filter_fieldname && '*'.
*                  APPEND ls_supplier_name TO lt_supplier_name.

                ELSE.
                  filter_error = 'Property:' && property_name && ' is not supported. '.
                  wrong_filter = abap_true.
                ENDIF.
              ELSE.
                wrong_filter = abap_true.
              ENDIF.
            ELSEIF left_node->kind = filter_node_kind-member.
              member ?= left_node.
              IF member->path->kind = filter_node_kind-property.
                property ?= member->path.
                property_name = property->property_name.
                IF property_name <> 'FIELD_NAME'.
                  filter_error = ' Only Filter Property FIELD_NAME is supported'.
                  wrong_filter = abap_true.
                ENDIF.
              ENDIF.
              IF member->source_object->kind = filter_node_kind-property.
                property ?= member->source_object.
                property_name = property->property_name.
                IF property_name <> 'TOFIELDS'.
                  filter_error = ' Only Navigation Property TOFIELDS is supported'.
                  wrong_filter = abap_true.
                ENDIF.
              ENDIF.

            ELSE.
              wrong_filter = abap_true.
            ENDIF.
          ENDIF.

          CLEAR function.
          CLEAR property.
          CLEAR literal.
          CLEAR function_parameters.
          CLEAR operator_name.
          CLEAR function_name.
          CLEAR property_name.

          IF right_node IS BOUND.
            IF right_node->kind = filter_node_kind-function.
*
*              function ?= right_node.
*              lv_function = function->function.
*              IF lv_function <> 'substringof'.
*                lv_filter_error = 'Only substringof is supported. '.
*                wrong_filter = abap_true.
*              ENDIF.
*
*              lt_param_tab = function->parameters.
*
*              IF lt_param_tab IS NOT INITIAL.
*
*                param1 = lt_param_tab[ 1 ].
*                IF param1->kind = filter_node_kind-literal.
*                  literal ?= param1.
*                  r_filter_fieldname = literal->literal_converted.
*                ELSE.
*                  wrong_filter = abap_true.
*                ENDIF.
*
*                param2 = lt_param_tab[ 2 ].
*                IF param2->kind = filter_node_kind-property.
*                  property ?= param2.
*                  lv_property = property->property_name.
*                ELSE.
*                  wrong_filter = abap_true.
*                ENDIF.
*
*                IF lv_property = 'SUPPLIER_NAME'.
*
*                  ls_supplier_name-sign  = 'I'.
*                  ls_supplier_name-option  ='CP'.
*                  ls_supplier_name-low  = '*' && r_filter_fieldname && '*'.
*                  APPEND ls_supplier_name TO lt_supplier_name.
*
*                ELSEIF lv_property = 'PRODUCT_ID'.
*
*                  ls_product_id-sign  = 'I'.
*                  ls_product_id-option  ='CP'.
*                  ls_product_id-low  = '*' && r_filter_fieldname && '*'.
*                  APPEND ls_product_id TO lt_product_id.
*
*                ELSE.
*                  " raise error message that filter string does not match the expected format
*                  " an additional property was found in the filter string
*                  lv_filter_error = 'Property:' && lv_property && ' is not supported. '.
*                  wrong_filter = abap_true.
*                ENDIF.
*              ELSE.
*                wrong_filter = abap_true.
*              ENDIF.
            ELSEIF right_node->kind = filter_node_kind-literal.
              literal ?= right_node.
              r_filter-search_field_name = literal->literal_converted.
            ELSE.
              wrong_filter = abap_true.
            ENDIF.
          ENDIF.

        ELSE.
          filter_error = ' Filter is not binary. '.
          wrong_filter = abap_true.
        ENDIF.

      ENDIF.

      IF wrong_filter = abap_true.

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            textid            = /iwbep/cx_mgw_busi_exception=>business_error_unlimited
            message_unlimited = filter_error && supported_filter_string.

      ENDIF.
    ENDIF.

  ENDMETHOD.


  METHOD properties_get_entity.

    DATA converted_keys LIKE er_entity.

    io_tech_request_context->get_converted_keys( IMPORTING es_key_values = converted_keys ).

    DATA(property) = api->get_property_by_id( converted_keys-property_id ).

    er_entity = CORRESPONDING #( property ).

  ENDMETHOD.


  METHOD properties_get_entityset.

    CASE iv_source_name.
      WHEN 'Datasource'.
        DATA ds_keys TYPE /cadaxo/cl_mds_mpc_ext=>ts_datasource.
        io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = ds_keys ).
        DATA(properties) = api->get_properties_by_dsid( ds_keys-ds_id ).

      WHEN 'Field'.
        DATA field_keys TYPE /cadaxo/cl_mds_mpc_ext=>ts_field.
        io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = field_keys ).
        properties = api->get_properties_by_fieldid( field_keys-field_id ).

    ENDCASE.

    et_entityset = CORRESPONDING #( properties ).

  ENDMETHOD.


  method ROOTDATASOURCES_GET_ENTITY.

      DATA converted_keys TYPE /cadaxo/cl_mds_mpc_ext=>ts_rootdatasource.

    io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = converted_keys ).
**TRY.
*SUPER->ROOTDATASOURCES_GET_ENTITY(
*  EXPORTING
*    IV_ENTITY_NAME          = IV_ENTITY_NAME
*    IV_ENTITY_SET_NAME      = IV_ENTITY_SET_NAME
*    IV_SOURCE_NAME          = IV_SOURCE_NAME
*    IT_KEY_TAB              = IT_KEY_TAB
**    io_request_object       = io_request_object
**    io_tech_request_context = io_tech_request_context
*    IT_NAVIGATION_PATH      = IT_NAVIGATION_PATH
**  IMPORTING
**    er_entity               = er_entity
**    es_response_context     = es_response_context
*       ).
** CATCH /iwbep/cx_mgw_busi_exception .
** CATCH /iwbep/cx_mgw_tech_exception .
**ENDTRY.
  endmethod.


  method ROOTDATASOURCES_GET_ENTITYSET.

    DATA converted_keys TYPE /cadaxo/cl_mds_mpc_ext=>ts_rootdatasource.
    DATA dss TYPE /cadaxo/if_mds_api=>ty_datasources.

    io_tech_request_context->get_converted_source_keys( IMPORTING es_key_values = converted_keys ).

    TRY.
      dss = api->get_datasources_by_id( i_ds_id  = converted_keys-ds_id ).
    CATCH /cadaxo/cx_mds_id INTO DATA(exception).
      RAISE EXCEPTION TYPE  /iwbep/cx_mgw_busi_exception EXPORTING textid = exception->if_t100_message~t100key.
    ENDTRY.

    LOOP AT dss ASSIGNING FIELD-SYMBOL(<ds>) WHERE ds_id <> converted_keys-ds_id.

        IF line_exists( et_entityset[ object_type = <ds>-type ] ).
            et_entityset[ object_type = <ds>-type ]-count = et_entityset[ object_type = <ds>-type ]-count + 1.
        ELSE.
            APPEND VALUE #( ds_id =  converted_keys-ds_id object_type = <ds>-type count = 1 ) TO et_entityset.
        ENDIF.
    ENDLOOP.

  endmethod.
ENDCLASS.
