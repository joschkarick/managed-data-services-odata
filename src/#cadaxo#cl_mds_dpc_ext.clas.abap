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
**********************************************************************

    DATA : lo_filter_tree             TYPE REF TO /iwbep/if_mgw_expr_node,
           lo_left_node               TYPE REF TO /iwbep/if_mgw_expr_node,
           lo_right_node              TYPE REF TO /iwbep/if_mgw_expr_node,
           lo_binary                  TYPE REF TO /iwbep/if_mgw_expr_binary,
           lo_function                TYPE REF TO /iwbep/if_mgw_expr_function,
           lo_property                TYPE REF TO /iwbep/if_mgw_expr_property,
           lo_literal                 TYPE REF TO /iwbep/if_mgw_expr_literal,
           lo_member                  TYPE REF TO /iwbep/if_mgw_expr_member,
           lt_param_tab               TYPE /iwbep/if_mgw_expr_function=>parameter_t,
           ls_param_tab               TYPE LINE OF /iwbep/if_mgw_expr_function=>parameter_t,
           lv_operator                TYPE string,
           lv_function                TYPE string,
           lv_literal                 TYPE string,
           lv_property                TYPE string,
           lv_supported_filter_string TYPE string,
           lv_filter_error            TYPE string,
           lv_wrong_filter            TYPE abap_bool,
           lt_filter_select_options   TYPE /iwbep/t_mgw_select_option.

    CONSTANTS: BEGIN OF filter_node_kind,
                 unary    TYPE c LENGTH 1 VALUE 'U',
                 binary   TYPE c LENGTH 1 VALUE 'B',
                 literal  TYPE c LENGTH 1 VALUE 'C',
                 function TYPE c LENGTH 1 VALUE 'F',
                 member   TYPE c LENGTH 1 VALUE 'M',
                 property TYPE c LENGTH 1 VALUE 'P',
               END OF filter_node_kind.

    DATA: lt_headerdata        TYPE STANDARD TABLE OF bapi_epm_product_header,
          ls_headerdata        TYPE                   bapi_epm_product_header,
          ls_entity            LIKE LINE OF           et_entityset,
          lt_product_id        TYPE TABLE OF          bapi_epm_product_id_range,
          ls_product_id        TYPE                   bapi_epm_product_id_range,
          lt_supplier_name     TYPE TABLE OF          bapi_epm_supplier_name_range,
          ls_supplier_name     TYPE                   bapi_epm_supplier_name_range,
          lt_category          TYPE TABLE OF          bapi_epm_product_categ_range,
          ls_category          TYPE                   bapi_epm_product_categ_range,
          lt_return            TYPE TABLE OF          bapiret2,
          lo_message_container TYPE REF TO            /iwbep/if_message_container.



    lv_wrong_filter = abap_false.

    lv_supported_filter_string = 'Only the following filterstring is supported: substringof(<some string>,SupplierName) or substringof(<some string>,ProductID)'.


    lt_filter_select_options = io_tech_request_context->get_filter( )->get_filter_select_options( ).

    IF lt_filter_select_options IS NOT INITIAL.

      "implement coding to retrieve data via select options

    ELSE.

      lo_filter_tree = io_tech_request_context->get_filter_expression_tree( ).

      IF lo_filter_tree IS BOUND.
        IF lo_filter_tree->kind = filter_node_kind-binary.

          lo_filter_tree->prepare_converted_values( ).
          lo_binary ?= lo_filter_tree.
          lv_operator = lo_binary->operator.
          lo_left_node  = lo_binary->left_operand.
          lo_right_node = lo_binary->right_operand.

          IF lo_left_node IS BOUND.
            IF lo_left_node->kind = filter_node_kind-function.

              lo_function ?= lo_left_node.
              lv_function = lo_function->function.
              IF lv_function <> 'substringof'.
                lv_filter_error = 'Only substringof is supported. '.
                lv_wrong_filter = abap_true.
              ENDIF.

              lt_param_tab = lo_function->parameters.

              IF lt_param_tab IS NOT INITIAL.

                DATA(param1) = lt_param_tab[ 1 ].
                IF param1->kind = filter_node_kind-literal.
                  lo_literal ?= param1.
                  lv_literal = lo_literal->literal_converted.
                ELSE.
                  lv_wrong_filter = abap_true.
                ENDIF.
                DATA(param2) = lt_param_tab[ 2 ].
                IF param2->kind = filter_node_kind-property.
                  lo_property ?= param2.
                  lv_property = lo_property->property_name.
                ELSE.
                  lv_wrong_filter = abap_true.
                ENDIF.

                IF lv_property = 'FIELD_NAME'.

                  ls_supplier_name-sign  = 'I'.
                  ls_supplier_name-option  ='CP'.
                  ls_supplier_name-low  = '*' && lv_literal && '*'.
                  APPEND ls_supplier_name TO lt_supplier_name.

                ELSEIF lv_property = 'FIELDNAME'.

                  ls_product_id-sign  = 'I'.
                  ls_product_id-option  ='CP'.
                  ls_product_id-low  = '*' && lv_literal && '*'.
                  APPEND ls_product_id TO lt_product_id.

                ELSE.
                  " raise error message that filter string does not match the expected format
                  " an additional property was found in the filter string
                  lv_filter_error = 'Property:' && lv_property && ' is not supported. '.
                  lv_wrong_filter = abap_true.
                ENDIF.
              ELSE.
                lv_wrong_filter = abap_true.
              ENDIF.
            ELSEIF lo_left_node->kind = filter_node_kind-member.
              lo_member ?= lo_left_node.
              IF lo_member->path->kind = filter_node_kind-property.
                lo_property ?= lo_member->path.
                lv_property = lo_property->property_name.
                IF lv_property <> 'FIELD_NAME'.
                  lv_filter_error = ' Only Filter Property FIELD_NAME is supported'.
                  lv_wrong_filter = abap_true.
                ENDIF.
              ENDIF.
              IF lo_member->source_object->kind = filter_node_kind-property.
                lo_property ?= lo_member->source_object.
                lv_property = lo_property->property_name.
                IF lv_property <> 'TOFIELDS'.
                  lv_filter_error = ' Only Navigation Property TOFIELDS is supported'.
                  lv_wrong_filter = abap_true.
                ENDIF.
              ENDIF.

            ELSE.
              lv_wrong_filter = abap_true.
            ENDIF.
          ENDIF.

          CLEAR lo_function.
          CLEAR lo_property.
          CLEAR lo_literal.
          CLEAR lt_param_tab.
          CLEAR ls_param_tab.
          CLEAR lv_operator.
          CLEAR lv_function.
          CLEAR lv_literal.
          CLEAR lv_property.

          IF lo_right_node IS BOUND.
            IF lo_right_node->kind = filter_node_kind-function.

              lo_function ?= lo_right_node.
              lv_function = lo_function->function.
              IF lv_function <> 'substringof'.
                lv_filter_error = 'Only substringof is supported. '.
                lv_wrong_filter = abap_true.
              ENDIF.

              lt_param_tab = lo_function->parameters.

              IF lt_param_tab IS NOT INITIAL.

                param1 = lt_param_tab[ 1 ].
                IF param1->kind = filter_node_kind-literal.
                  lo_literal ?= param1.
                  lv_literal = lo_literal->literal_converted.
                ELSE.
                  lv_wrong_filter = abap_true.
                ENDIF.

                param2 = lt_param_tab[ 2 ].
                IF param2->kind = filter_node_kind-property.
                  lo_property ?= param2.
                  lv_property = lo_property->property_name.
                ELSE.
                  lv_wrong_filter = abap_true.
                ENDIF.

                IF lv_property = 'SUPPLIER_NAME'.

                  ls_supplier_name-sign  = 'I'.
                  ls_supplier_name-option  ='CP'.
                  ls_supplier_name-low  = '*' && lv_literal && '*'.
                  APPEND ls_supplier_name TO lt_supplier_name.

                ELSEIF lv_property = 'PRODUCT_ID'.

                  ls_product_id-sign  = 'I'.
                  ls_product_id-option  ='CP'.
                  ls_product_id-low  = '*' && lv_literal && '*'.
                  APPEND ls_product_id TO lt_product_id.

                ELSE.
                  " raise error message that filter string does not match the expected format
                  " an additional property was found in the filter string
                  lv_filter_error = 'Property:' && lv_property && ' is not supported. '.
                  lv_wrong_filter = abap_true.
                ENDIF.
              ELSE.
                lv_wrong_filter = abap_true.
              ENDIF.
            ELSEIF lo_right_node->kind = filter_node_kind-literal.
              lo_literal ?= lo_right_node.
              lv_literal = lo_literal->literal_converted.
            ELSE.
              lv_wrong_filter = abap_true.
            ENDIF.
          ENDIF.

        ELSE.
          lv_filter_error = ' Filter is not binary. '.
          lv_wrong_filter = abap_true.
        ENDIF.



      ENDIF.

      IF lv_wrong_filter = abap_true.

        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            textid            = /iwbep/cx_mgw_busi_exception=>business_error_unlimited
            message_unlimited = lv_filter_error && lv_supported_filter_string.

      ENDIF.
    ENDIF.



**********************************************************************
    DATA(filter) = io_tech_request_context->get_filter( ).
    DATA(filter_so) = filter->get_filter_select_options( ).


    IF object_semantic_key IS NOT INITIAL.
      DATA(dss) = api->get_datasources_by_semkey( i_ds_semkey        = object_semantic_key
                                                  i_fieldname_filter = CONV #( lv_literal ) ).

      LOOP AT dss ASSIGNING FIELD-SYMBOL(<ds>).

        APPEND CORRESPONDING #( <ds>-api->get_datasource( ) MAPPING object_name = name object_type = type ) TO et_entityset ASSIGNING FIELD-SYMBOL(<entity>).

        <entity>-link = CORRESPONDING #( <ds>-api->get_action_links( ) ).
        <entity>-field_search = <ds>-field_search.

        <entity>-object_state = SWITCH #( <ds>-role WHEN /cadaxo/if_mds_api=>ds_role-main THEN 100
                                                    WHEN /cadaxo/if_mds_api=>ds_role-parent THEN 110
                                                    WHEN /cadaxo/if_mds_api=>ds_role-child THEN 120 ).
        IF lv_literal IS NOT INITIAL AND <ds>-field_search IS INITIAL.
          <entity>-object_state = <entity>-object_state + 100.
        ENDIF.
      ENDLOOP.

    ELSE.

    ENDIF.
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
      ENDCASE.
    ENDIF.

    DATA(nodes) = api->get_datasources_by_id( i_ds_id = converted_keys-ds_id ).
    DATA(nodeapi) = nodes[ 1 ]-api.

    er_entity = CORRESPONDING #( nodes[ 1 ] MAPPING object_name = name object_type = type ).
    er_entity-link = nodeapi->get_action_links(  ).
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

    DATA(filter) = io_tech_request_context->get_filter( ).
    DATA(filter_so) = filter->get_filter_select_options( ).
*filter->

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
