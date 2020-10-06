CLASS /cadaxo/cl_mds_dpc_ext DEFINITION
  PUBLIC
  INHERITING FROM /cadaxo/cl_mds_dpc
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-METHODS class_constructor.

  PROTECTED SECTION.
    METHODS datasources_get_entityset REDEFINITION.
    METHODS datasources_get_entity REDEFINITION.
  PRIVATE SECTION.
    CLASS-DATA: api TYPE REF TO /cadaxo/if_mds_api.
ENDCLASS.



CLASS /cadaxo/cl_mds_dpc_ext IMPLEMENTATION.

  METHOD class_constructor.
    api = /cadaxo/cl_mds_api=>get_instance( ).
  ENDMETHOD.

  METHOD datasources_get_entityset.
    DATA: object_name TYPE /cadaxo/mds_object_name,
          object_type TYPE /cadaxo/mds_object_type.

    SPLIT iv_search_string AT '|' INTO object_name object_type.

    DATA(nodes) = api->get_datasources_by_semkey( value #( name = object_name type = object_type ) ).

* name  type /cadaxo/mds_object_name
* type  type /cadaxo/mds_object_type
* ds_id  type /cadaxo/mds_ds_id
* changed_by  type as4user
* changed_at  type timestampl
* description  type as4text
*
* ds_id  type /cadaxo/mds_ds_id
* object_type  type /cadaxo/mds_object_type
* object_name  type /cadaxo/mds_object_name
* description  type c length 60
* link  type /cadaxo/mds_od_ds_link
* object_state  type i
* managed  type /cadaxo/mds_od_managed


    et_entityset = CORRESPONDING #( nodes MAPPING object_name = name object_type = type ).


  ENDMETHOD.

  METHOD datasources_get_entity.

    DATA converted_keys LIKE er_entity.

    io_tech_request_context->get_converted_keys( IMPORTING es_key_values = converted_keys ).



  ENDMETHOD.

ENDCLASS.
