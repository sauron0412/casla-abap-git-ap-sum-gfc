CLASS zcl_ap_summary_logic DEFINITION
  PUBLIC
  FINAL

    INHERITING FROM cx_rap_query_provider

  CREATE PUBLIC.
  PUBLIC SECTION.

    INTERFACES if_rap_query_provider.

  PROTECTED SECTION.
  PRIVATE SECTION.

    " Define line item structure internally
    TYPES: BEGIN OF ty_range_option,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE string,
             high   TYPE string,
           END OF ty_range_option,

           tt_ranges TYPE TABLE OF ty_range_option.
    DATA: gt_ttusd TYPE TABLE OF zc_ttusd.
    TYPES: BEGIN OF ty_returns,
             msgty TYPE symsgty,  "char(1) Message Type
             msgid TYPE symsgid,  "char(20) Message Class
             msgno TYPE symsgno,  "numc(3) Message Number
             msgv1 TYPE symsgv,   "char(50) Message Variable
             msgv2 TYPE symsgv,   "char(50) Message Variable
             msgv3 TYPE symsgv,   "char(50) Message Variable
             msgv4 TYPE symsgv,
           END OF ty_returns,

           tt_returns TYPE STANDARD TABLE OF ty_returns WITH EMPTY KEY.
ENDCLASS.



CLASS ZCL_AP_SUMMARY_LOGIC IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    TYPES: BEGIN OF lty_range_option,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE string,
             high   TYPE string,
           END OF lty_range_option.
    DATA : lt_open_balances TYPE TABLE OF zst_open_balances.
    DATA: lt_result        TYPE TABLE OF zc_accpay_summary,
          lv_start_date    TYPE zc_accpay_summary-p_start_date,
          lv_end_date      TYPE zc_accpay_summary-p_end_date,
          lt_range         TYPE TABLE OF lty_range_option,
          lv_compcode_prov TYPE abap_bool,
          lv_bpgroup_prov  TYPE abap_bool,
          lv_account_prov  TYPE abap_bool,
          lv_partner_prov  TYPE abap_bool,
          lv_currency_prov TYPE abap_bool,
          lt_items         TYPE TABLE OF zst_item,
          ls_items         TYPE zst_item,
          lr_companycode   TYPE RANGE OF i_journalentryitem-companycode,
          lr_bpgroup       TYPE RANGE OF i_businesspartner-businesspartnergrouping,
          lr_account       TYPE RANGE OF i_journalentryitem-glaccount,
          lr_partner       TYPE RANGE OF i_journalentryitem-supplier,
          lv_currency      TYPE zc_accpay_summary-companycodecurrency,
          lr_currency      TYPE RANGE OF i_journalentryitem-transactioncurrency.
    CLEAR: lt_result.
* test new
    DATA: lt_returns TYPE tt_returns.

    " 1. Extract filter parameters
    CHECK io_request IS BOUND.
    TRY.
        DATA(lo_filter) = io_request->get_filter( ).
        CHECK lo_filter IS BOUND.
        DATA(lt_filter_ranges) = lo_filter->get_as_ranges( ).

        " Mandatory date filters
        READ TABLE lt_filter_ranges INTO DATA(ls_start_date) WITH KEY name = 'P_START_DATE'.
        IF sy-subrc = 0 AND ls_start_date-range IS NOT INITIAL.
          lv_start_date = ls_start_date-range[ 1 ]-low.
        ENDIF.

        READ TABLE lt_filter_ranges INTO DATA(ls_end_date) WITH KEY name = 'P_END_DATE'.
        IF sy-subrc = 0 AND ls_end_date-range IS NOT INITIAL.
          lv_end_date = ls_end_date-range[ 1 ]-low.
        ENDIF.
        "Mandatory currency filter
*        READ TABLE lt_filter_ranges INTO DATA(ls_currency) WITH KEY name = 'RHCUR'.
*        IF sy-subrc = 0 AND ls_currency-range IS NOT INITIAL.
*          lv_currency = ls_currency-range[ 1 ]-low.
*        ENDIF.

        " Optional filters with ALPHA conversion

        TRY.
            DATA(lr_currency_raw) = lt_filter_ranges[ name = 'RHCUR' ]-range.
            LOOP AT lr_currency_raw ASSIGNING FIELD-SYMBOL(<fs_currency>).
              IF <fs_currency>-low IS NOT INITIAL.
                <fs_currency>-low = |{ <fs_currency>-low ALPHA = IN WIDTH = 5 }|.
              ENDIF.
              IF <fs_currency>-high IS NOT INITIAL.
                <fs_currency>-high = |{ <fs_currency>-high ALPHA = IN WIDTH = 5 }|.
              ENDIF.
            ENDLOOP.
            MOVE-CORRESPONDING lr_currency_raw TO lr_currency.
            lv_currency_prov = abap_true.
          CATCH cx_sy_itab_line_not_found.
            CLEAR lr_currency.
        ENDTRY.


        TRY.
            DATA(lr_compcode_raw) = lt_filter_ranges[ name = 'RBUKRS' ]-range.
            LOOP AT lr_compcode_raw ASSIGNING FIELD-SYMBOL(<fs_compcode>).
              IF <fs_compcode>-low IS NOT INITIAL.
                <fs_compcode>-low = |{ <fs_compcode>-low ALPHA = IN WIDTH = 4 }|.
              ENDIF.
              IF <fs_compcode>-high IS NOT INITIAL.
                <fs_compcode>-high = |{ <fs_compcode>-high ALPHA = IN WIDTH = 4 }|.
              ENDIF.
            ENDLOOP.
            MOVE-CORRESPONDING lr_compcode_raw TO lr_companycode.
            lv_compcode_prov = abap_true.
          CATCH cx_sy_itab_line_not_found.
            CLEAR lr_companycode.
        ENDTRY.

        TRY.
            DATA(lr_partner_raw) = lt_filter_ranges[ name = 'BP' ]-range.
            LOOP AT lr_partner_raw ASSIGNING FIELD-SYMBOL(<fs_partner>).
              IF <fs_partner>-low IS NOT INITIAL.
                <fs_partner>-low = |{ <fs_partner>-low ALPHA = IN WIDTH = 10 }|.
              ENDIF.
              IF <fs_partner>-high IS NOT INITIAL.
                <fs_partner>-high = |{ <fs_partner>-high ALPHA = IN WIDTH = 10 }|.
              ENDIF.
            ENDLOOP.
            MOVE-CORRESPONDING lr_partner_raw TO lr_partner.
            lv_partner_prov = abap_true.
          CATCH cx_sy_itab_line_not_found.
            CLEAR lr_partner.
        ENDTRY.

        TRY.
            DATA(lr_account_raw) = lt_filter_ranges[ name = 'ACCOUNTNUMBER' ]-range.
            LOOP AT lr_account_raw ASSIGNING FIELD-SYMBOL(<fs_account>).
              IF <fs_account>-low IS NOT INITIAL.
                <fs_account>-low = |{ <fs_account>-low ALPHA = IN WIDTH = 10 }|.
              ENDIF.
              IF <fs_account>-high IS NOT INITIAL.
                <fs_account>-high = |{ <fs_account>-high ALPHA = IN WIDTH = 10 }|.
              ENDIF.
            ENDLOOP.
            MOVE-CORRESPONDING lr_account_raw TO lr_account.
            lv_account_prov = abap_true.
          CATCH cx_sy_itab_line_not_found.
            CLEAR lr_account.
        ENDTRY.

        TRY.
            DATA(lr_bpgroup_raw) = lt_filter_ranges[ name = 'BP_GR' ]-range.
            LOOP AT lr_bpgroup_raw ASSIGNING FIELD-SYMBOL(<fs_bpgr>).
              IF <fs_bpgr>-low IS NOT INITIAL.
                <fs_bpgr>-low = |{ <fs_bpgr>-low ALPHA = IN WIDTH = 4 }|.
              ENDIF.
              IF <fs_bpgr>-high IS NOT INITIAL.
                <fs_bpgr>-high = |{ <fs_bpgr>-high ALPHA = IN WIDTH = 4 }|.
              ENDIF.
            ENDLOOP.
            MOVE-CORRESPONDING lr_bpgroup_raw TO lr_bpgroup.
            lv_bpgroup_prov = abap_true.
          CATCH cx_sy_itab_line_not_found.
            CLEAR lr_bpgroup.
        ENDTRY.

      CATCH cx_rap_query_filter_no_range INTO DATA(lx_filter_error).
        " Log error or raise message for debugging
        RETURN.
    ENDTRY.

    READ TABLE lt_filter_ranges INTO DATA(ls_fillter) WITH KEY name = 'CAN_TRU'.
    IF sy-subrc = 0.
      READ TABLE ls_fillter-range INTO DATA(ls_cantru) INDEX 1.
      IF ls_cantru-low = 'X' OR ls_cantru-low = 'true'.
        DATA(can_tru) = 'X'.
      ENDIF.
    ENDIF.

    IF lv_start_date > lv_end_date.
      APPEND VALUE #(
        msgty = 'E'
        msgid = 'ZAPSUMDAT'
        msgno = '001'
        msgv1 = |Ngày từ { lv_start_date } đến { lv_end_date } không hợp lệ|
*        msgv2 =
      ) TO lt_returns.
    ENDIF.

    READ TABLE lt_returns INDEX 1 INTO DATA(ls_return).
    IF sy-subrc = 0.
      RAISE EXCEPTION TYPE zcl_cttt_ban
        EXPORTING
          textid = VALUE scx_t100key(
                     msgid = 'ZAPSUMDAT'
                     msgno = ls_return-msgno
                     attr1 = CONV string( ls_return-msgv1 )
*                     attr2 =
      ).
      RETURN.
    ENDIF.

    " get company name and address
    DATA: lw_company          TYPE bukrs,
          ls_companycode_info TYPE zst_companycode_info.
    lw_company = lr_companycode[ 1 ]-low.

    AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
       ID 'ACTVT' FIELD '03'
       ID 'ZBUKRS' FIELD lw_company.
    IF sy-subrc <> 0.
*      CHECK 1 = 2.
*      lw_company = 'XXXX'.
    ENDIF.

    CALL METHOD zcl_jp_common_core=>get_companycode_details
      EXPORTING
        i_companycode = lw_company
      IMPORTING
        o_companycode = ls_companycode_info.

    SELECT * FROM zc_ttusd
        WHERE companycode IN @lr_companycode
        AND  glaccount IN @lr_account
        AND glaccount NOT LIKE '341%'
        AND postingdate <= @lv_end_date
        AND financialaccounttype = 'K'
         AND supplier IN @lr_partner
         AND ( accountingdocumenttype = 'KZ' OR accountingdocumenttype = 'KJ' )
         INTO TABLE @gt_ttusd.
    SORT gt_ttusd BY companycode fiscalyear accountingdocument accountingdocumentitem.
    DATA: lt_where_clauses TYPE TABLE OF string.
    APPEND | postingdate >= @lv_start_date AND postingdate <= @lv_end_date| TO lt_where_clauses.
    APPEND |AND financialaccounttype = 'K'| TO lt_where_clauses.
    APPEND |AND supplier IS NOT NULL| TO lt_where_clauses.
    APPEND |AND debitcreditcode IN ('S', 'H')| TO lt_where_clauses.
    APPEND |AND ledger = '0L'| TO lt_where_clauses.
    APPEND |AND glaccount NOT LIKE '341%'| TO lt_where_clauses.

    IF lv_compcode_prov = abap_true.
      APPEND |AND companycode IN @lr_companycode| TO lt_where_clauses.
    ENDIF.
    IF lv_partner_prov = abap_true.
      APPEND |AND supplier IN @lr_partner| TO lt_where_clauses.
    ENDIF.
    IF lv_account_prov = abap_true.
      APPEND |AND glaccount IN @lr_account| TO lt_where_clauses.
    ENDIF.

    READ TABLE lr_currency INTO DATA(ls_curr) INDEX 1.

    IF lv_currency_prov = abap_true AND ls_curr-low NE 'VND'.
      APPEND |AND transactioncurrency IN @lr_currency| TO lt_where_clauses.
    ENDIF.

    " 2. Aggregate supplier data from I_JournalEntryItem
    " select total debit and credit amounts for each supplier, company code, currency, and GL account in period
*    SELECT companycode AS rbukrs,
*           supplier AS bp,
*           transactioncurrency AS rhcur,
*           glaccount AS accountnumber,
*           companycodecurrency,
*           SUM( CASE WHEN debitcreditcode = 'S' THEN amountincompanycodecurrency ELSE 0 END ) AS total_debit,
*           SUM( CASE WHEN debitcreditcode = 'H' THEN amountincompanycodecurrency ELSE 0 END ) AS total_credit,
*           SUM( CASE WHEN debitcreditcode = 'S' THEN amountintransactioncurrency ELSE 0 END ) AS total_debit_tran,
*           SUM( CASE WHEN debitcreditcode = 'H' THEN amountintransactioncurrency ELSE 0 END ) AS total_credit_tran
*      FROM i_journalentryitem
*      WHERE (lt_where_clauses)
*      GROUP BY companycode, supplier, companycodecurrency, glaccount, transactioncurrency
*      INTO CORRESPONDING FIELDS OF TABLE @lt_items.
*    SORT lt_items BY bp.

*    DATA: ls_items LIKE LINE OF lt_items.

    SELECT companycode AS rbukrs,
           accountingdocument,
           fiscalyear,
           accountingdocumentitem,
           glaccount AS accountnumber,
           accountingdocumenttype,
           supplier AS bp,
           transactioncurrency AS rhcur,
           isreversed,
           reversalreferencedocument,
           reversalreferencedocumentcntxt,
           debitcreditcode,
           amountincompanycodecurrency,
           amountintransactioncurrency,
           transactioncurrency,
           companycodecurrency,
           clearingaccountingdocument,
           customer,
           supplier,
           financialaccounttype,
           ledgergllineitem
        FROM i_journalentryitem
        WHERE (lt_where_clauses)
        INTO TABLE @DATA(lt_items_temp).
    SORT lt_items_temp BY rbukrs accountnumber fiscalyear ASCENDING.

    IF sy-subrc EQ 0.
      SELECT companycode,
             fiscalyear,
             accountingdocument,
             isreversal,
             isreversed,
             reversedocument,
             originalreferencedocument
          FROM i_journalentry
          FOR ALL ENTRIES IN @lt_items_temp
          WHERE companycode = @lt_items_temp-rbukrs
          AND accountingdocument = @lt_items_temp-accountingdocument
          AND fiscalyear = @lt_items_temp-fiscalyear
          INTO TABLE @DATA(lt_journal_headers).
      SORT lt_journal_headers BY companycode accountingdocument fiscalyear ASCENDING.
    ENDIF.
*    loaij ctu can tru
    IF can_tru = 'X'.
      LOOP AT lt_items_temp INTO DATA(ls_cantru_item).
        ls_cantru_item-amountincompanycodecurrency = ls_cantru_item-amountincompanycodecurrency * -1.
        ls_cantru_item-amountintransactioncurrency = ls_cantru_item-amountintransactioncurrency * -1.
        LOOP AT lt_items_temp INTO DATA(ls_del)
                              WHERE accountnumber = ls_cantru_item-accountnumber
                               AND accountingdocument = ls_cantru_item-accountingdocument
                               AND financialaccounttype = ls_cantru_item-financialaccounttype
                               AND supplier = ls_cantru_item-supplier
                               AND customer = ls_cantru_item-customer
                               AND amountincompanycodecurrency = ls_cantru_item-amountincompanycodecurrency
                               AND amountintransactioncurrency = ls_cantru_item-amountintransactioncurrency.

          DELETE lt_items_temp WHERE accountingdocument = ls_cantru_item-accountingdocument AND fiscalyear = ls_cantru_item-fiscalyear
                                AND  ledgergllineitem = ls_cantru_item-ledgergllineitem.
          DELETE lt_items_temp WHERE accountingdocument = ls_del-accountingdocument AND fiscalyear = ls_del-fiscalyear
                                AND  ledgergllineitem = ls_del-ledgergllineitem.
          EXIT.
        ENDLOOP.
      ENDLOOP.
    ENDIF.


    " loại bỏ cặp chứng từ hủy cùng kỳ.
    DATA: lt_huy          LIKE lt_items_temp,
          ls_huy          LIKE LINE OF lt_huy,
          lw_thanhtoan_nt TYPE char1,
          lv_index_huy    TYPE sy-tabix,

          lv_length       TYPE n LENGTH 3,
          lv_docnum       TYPE i_journalentryitem-accountingdocument,
          lv_year         TYPE i_journalentryitem-fiscalyear.

    lt_huy = lt_items_temp.


    SORT lt_huy BY rbukrs accountingdocument fiscalyear ASCENDING.

    LOOP AT lt_huy INTO DATA(ls_check_item) WHERE isreversed IS NOT INITIAL.
      lv_index_huy = sy-tabix.

      READ TABLE lt_journal_headers INTO DATA(ls_check_header) WITH KEY companycode = ls_check_item-rbukrs
                                                                        accountingdocument = ls_check_item-accountingdocument
                                                                        fiscalyear = ls_check_item-fiscalyear BINARY SEARCH.

      IF sy-subrc = 0.
        lv_length = strlen( ls_check_header-originalreferencedocument ) - 4.
        lv_docnum = ls_check_header-originalreferencedocument(lv_length).
        lv_year = ls_check_header-originalreferencedocument+lv_length.

        IF lv_docnum IS NOT INITIAL.
          DELETE lt_items_temp WHERE reversalreferencedocument = lv_docnum AND fiscalyear = lv_year.
          IF sy-subrc = 0.
            DELETE lt_items_temp WHERE accountingdocument = ls_check_item-accountingdocument AND fiscalyear = lv_year.
          ENDIF.
        ENDIF.
      ENDIF.

      CLEAR: ls_check_item, ls_check_header, lv_length, lv_docnum, lv_year.
    ENDLOOP.

    DATA: lw_tienusd TYPE i_operationalacctgdocitem-amountintransactioncurrency.
    SORT lt_items_temp BY rbukrs fiscalyear accountingdocument accountingdocumentitem.
    LOOP AT lt_items_temp ASSIGNING FIELD-SYMBOL(<fs_acdoca>) WHERE
        financialaccounttype = 'K' AND transactioncurrency = 'VND' AND ( accountingdocumenttype = 'KZ' OR accountingdocumenttype = 'KJ' ).

      READ TABLE gt_ttusd INTO DATA(ls_tyle) WITH KEY companycode = <fs_acdoca>-rbukrs
                                                        fiscalyear = <fs_acdoca>-fiscalyear
                                                        accountingdocument = <fs_acdoca>-accountingdocument
                                                        accountingdocumentitem = <fs_acdoca>-accountingdocumentitem
                                                        BINARY SEARCH.
      IF sy-subrc = 0.
        IF sy-subrc = 0.
          REPLACE ALL OCCURRENCES OF ',' IN ls_tyle-reference1idbybusinesspartner WITH '.'.
          CONDENSE ls_tyle-reference1idbybusinesspartner.
          TRY.
              <fs_acdoca>-amountintransactioncurrency = <fs_acdoca>-amountintransactioncurrency * ls_tyle-reference1idbybusinesspartner / ls_tyle-amountintransactioncurrency.
              <fs_acdoca>-transactioncurrency = 'USD'.
              lw_tienusd = lw_tienusd + <fs_acdoca>-amountintransactioncurrency.

              AT END OF accountingdocumentitem.
                <fs_acdoca>-amountintransactioncurrency = ls_tyle-reference1idbybusinesspartner - lw_tienusd + <fs_acdoca>-amountintransactioncurrency.
                CLEAR: lw_tienusd.
              ENDAT.
            CATCH cx_root INTO DATA(err).
          ENDTRY.
        ENDIF.
      ENDIF.
    ENDLOOP.

    FREE: lt_items.


    LOOP AT lt_items_temp INTO DATA(lg_journal_items)
    GROUP BY (
        companycode = lg_journal_items-rbukrs
        glaccount = lg_journal_items-accountnumber
        supplier =  lg_journal_items-bp
        companycodecurrency = lg_journal_items-companycodecurrency
        transactioncurrency = lg_journal_items-rhcur
    ) ASSIGNING FIELD-SYMBOL(<group>).
      ls_items-rbukrs = <group>-companycode.
      ls_items-bp = <group>-supplier.
      ls_items-accountnumber = <group>-glaccount.
      ls_items-companycodecurrency = <group>-companycodecurrency .
      ls_items-rhcur = <group>-transactioncurrency.

      LOOP AT lt_items_temp INTO DATA(ls_items_temp) WHERE rbukrs = <group>-companycode
                                                     AND accountnumber = <group>-glaccount
                                                     AND bp = <group>-supplier
                                                     AND companycodecurrency = <group>-companycodecurrency
                                                     AND transactioncurrency = <group>-transactioncurrency.
        CLEAR : lw_thanhtoan_nt.
        IF ls_items_temp-debitcreditcode = 'S'.
          " Code them chỗ này rồi đánh dấu vào, Điều kiện vịeet nam các kiểu => Đánh dấu thanh toán rồi cuối cùng đổi dấu
          IF ls_items_temp-transactioncurrency = 'VND' AND ls_items_temp-accountingdocument NE ls_items_temp-clearingaccountingdocument.
            SELECT
              SUM( amountintransactioncurrency ) AS amountintransactioncurrency ,
              transactioncurrency,
              supplier,
              glaccount
              FROM i_journalentryitem
              WHERE accountingdocument = @ls_items_temp-clearingaccountingdocument
              AND   companycode = @ls_items_temp-rbukrs
              AND fiscalyear = @ls_items_temp-fiscalyear
              AND debitcreditcode = 'H'
              AND transactioncurrency NE 'VND'
              AND financialaccounttype = 'K'
              AND ledger = '0L'
              GROUP BY transactioncurrency, supplier, glaccount
               INTO TABLE @DATA(lt_sum).
            READ TABLE lt_sum INTO DATA(ls_sum) INDEX 1.
            IF sy-subrc = 0.
              IF ls_sum-amountintransactioncurrency < 0.
                ls_sum-amountintransactioncurrency = ls_sum-amountintransactioncurrency * -1.
              ENDIF.
              ls_items-thanhtoannt = 'X'.
              lw_thanhtoan_nt = 'X'.
              ls_items-thanhtoan_nt = ls_sum-transactioncurrency.
              ls_items_temp-amountintransactioncurrency = ls_sum-amountintransactioncurrency.
            ENDIF.
          ENDIF.
          "
          ls_items-total_debit = ls_items-total_debit + ls_items_temp-amountincompanycodecurrency.
          IF lw_thanhtoan_nt = 'X' OR ls_items_temp-transactioncurrency NE 'VND'.
            ls_items-total_debit_tran = ls_items-total_debit_tran + ls_items_temp-amountintransactioncurrency.
          ENDIF.
        ELSEIF ls_items_temp-debitcreditcode = 'H'.
          ls_items-total_credit = ls_items-total_credit + ls_items_temp-amountincompanycodecurrency.
          IF ls_items_temp-transactioncurrency NE 'VND'.
            ls_items-total_credit_tran = ls_items-total_credit_tran + ls_items_temp-amountintransactioncurrency.
          ENDIF.
        ENDIF.

        CLEAR: ls_items_temp.
      ENDLOOP.

      APPEND ls_items TO lt_items.
      CLEAR: ls_items, lg_journal_items.
    ENDLOOP.



    DATA: lt_where_clauses_open TYPE TABLE OF string.

    APPEND | supplier IN @lr_partner| TO lt_where_clauses_open.
    APPEND |AND postingdate < @lv_start_date| TO lt_where_clauses_open.
    APPEND |AND companycode IN @lr_companycode| TO lt_where_clauses_open.
    APPEND |AND ledger = '0L'| TO lt_where_clauses_open.
    APPEND |AND financialaccounttype = 'K'| TO lt_where_clauses_open.
    APPEND |AND supplier IS NOT NULL| TO lt_where_clauses_open.
    APPEND |AND debitcreditcode IN ('S', 'H')| TO lt_where_clauses_open.
    APPEND |AND glaccount IN @lr_account| TO lt_where_clauses_open.
    APPEND |AND glaccount NOT LIKE '341%'| TO lt_where_clauses_open.

    IF lr_currency IS NOT INITIAL AND ls_curr-low NE 'VND'.
      APPEND |AND transactioncurrency IN @lr_currency| TO lt_where_clauses_open.
    ENDIF.

    " 3. Fetch open and end balances in bulk
    SELECT supplier AS bp,
           companycode AS rbukrs,
           SUM( CASE WHEN debitcreditcode = 'S' THEN amountincompanycodecurrency ELSE 0 END ) AS open_debit,
           SUM( CASE WHEN debitcreditcode = 'H' THEN amountincompanycodecurrency ELSE 0 END ) AS open_credit,
           SUM( CASE WHEN debitcreditcode = 'S' THEN amountintransactioncurrency ELSE 0 END ) AS open_debit_tran,
           SUM( CASE WHEN debitcreditcode = 'H' THEN amountintransactioncurrency ELSE 0 END ) AS open_credit_tran,
           companycodecurrency,
           transactioncurrency,
           glaccount
      FROM i_journalentryitem
      WHERE (lt_where_clauses_open)
      GROUP BY supplier, companycode, transactioncurrency, companycodecurrency, glaccount
      INTO CORRESPONDING FIELDS OF TABLE @lt_open_balances.
*    case thanh toán bằng usd
    DATA: lw_tienusd1 TYPE i_journalentryitem-amountincompanycodecurrency.
    LOOP AT lt_open_balances ASSIGNING FIELD-SYMBOL(<fs_open1>).
      LOOP AT gt_ttusd INTO DATA(ls_ttusd) WHERE companycode = <fs_open1>-rbukrs AND glaccount = <fs_open1>-glaccount
                                             AND supplier = <fs_open1>-bp AND postingdate < lv_start_date.
        IF <fs_open1>-transactioncurrency = 'VND'.
          IF ls_ttusd-debitcreditcode = 'S'.
            <fs_open1>-open_debit_tran = <fs_open1>-open_debit_tran - ls_ttusd-amountintransactioncurrency.
          ELSE.
            <fs_open1>-open_credit_tran = <fs_open1>-open_credit_tran - ls_ttusd-amountintransactioncurrency.
          ENDIF.
        ELSE.
          REPLACE ALL OCCURRENCES OF ',' IN ls_ttusd-reference1idbybusinesspartner WITH '.'.
          CONDENSE ls_ttusd-reference1idbybusinesspartner.
          TRY.
              lw_tienusd1 = ls_ttusd-reference1idbybusinesspartner.
              IF ls_ttusd-debitcreditcode = 'S'.
                <fs_open1>-open_debit_tran = <fs_open1>-open_debit_tran + lw_tienusd1.
              ELSE.
                <fs_open1>-open_credit_tran = <fs_open1>-open_credit_tran + lw_tienusd1.
              ENDIF.
            CATCH cx_root INTO err.
          ENDTRY.
        ENDIF.
        CLEAR: lw_tienusd1.
      ENDLOOP.
    ENDLOOP.

    SORT lt_open_balances BY rbukrs bp glaccount transactioncurrency companycodecurrency ASCENDING.

* Thanh toán VND cho khoản gốc ngoại tệ
*    LOOP AT lt_open_balances ASSIGNING FIELD-SYMBOL(<fs_clear>) WHERE  transactioncurrency = 'VND'.
*      CLEAR: <fs_clear>-open_debit_tran,<fs_clear>-open_credit_tran.
*    ENDLOOP.
*    IF ls_curr-low = 'VND' OR ls_curr-low = ''.
*      DATA : lw_index TYPE sy-tabix.
*      FREE: lt_where_clauses_open.
*      APPEND | supplier IN @lr_partner| TO lt_where_clauses_open.
*      APPEND |AND postingdate < @lv_start_date| TO lt_where_clauses_open.
*      APPEND |AND companycode IN @lr_companycode| TO lt_where_clauses_open.
*      APPEND |AND ledger = '0L'| TO lt_where_clauses_open.
*      APPEND |AND financialaccounttype = 'K'| TO lt_where_clauses_open.
*      APPEND |AND supplier IS NOT NULL| TO lt_where_clauses_open.
*      APPEND |AND debitcreditcode = 'S'| TO lt_where_clauses_open.
*      APPEND |AND glaccount IN @lr_account| TO lt_where_clauses_open.
*      APPEND |AND glaccount NOT LIKE '341%'| TO lt_where_clauses_open.
*
**    IF iv_currency IS NOT INITIAL.
*      APPEND |AND transactioncurrency = 'VND'| TO lt_where_clauses_open.
**    ENDIF.
*      SELECT accountingdocument,
*             companycode,
*             fiscalyear,
*           CASE WHEN debitcreditcode = 'S' THEN amountincompanycodecurrency ELSE 0 END  AS open_debit,
*           CASE WHEN debitcreditcode = 'H' THEN amountincompanycodecurrency ELSE 0 END  AS open_credit,
*           CASE WHEN debitcreditcode = 'S' THEN amountintransactioncurrency ELSE 0 END  AS open_debit_tran,
*           CASE WHEN debitcreditcode = 'H' THEN amountintransactioncurrency ELSE 0 END  AS open_credit_tran,
*          clearingaccountingdocument,
*          transactioncurrency,
*          companycodecurrency,
*          glaccount
*     FROM i_journalentryitem
*     WHERE (lt_where_clauses_open)
*     INTO TABLE @DATA(lt_thanhtoannt).
*      DELETE lt_thanhtoannt WHERE clearingaccountingdocument IS INITIAL.
*      LOOP AT lt_thanhtoannt INTO DATA(ls_thanhtoannt).
*        lw_index = sy-tabix.
*        IF ls_thanhtoannt-accountingdocument = ls_thanhtoannt-clearingaccountingdocument.
*          DELETE lt_thanhtoannt INDEX sy-tabix.
*        ELSE.
*          SELECT
*          SUM( amountintransactioncurrency ) AS amountintransactioncurrency ,
*          transactioncurrency,
*          supplier,
*          glaccount
*          FROM i_journalentryitem
*          WHERE accountingdocument = @ls_thanhtoannt-clearingaccountingdocument
*          AND   companycode = @ls_thanhtoannt-companycode
*          AND fiscalyear = @ls_thanhtoannt-fiscalyear
*          AND debitcreditcode = 'H'
*          AND transactioncurrency NE 'VND'
*          AND financialaccounttype = 'K'
*          AND ledger = '0L'
*          GROUP BY transactioncurrency, supplier, glaccount
*          INTO TABLE @DATA(lt_sum_open).
*          READ TABLE lt_sum_open INTO DATA(ls_sum_open) INDEX 1.
*          IF sy-subrc = 0.
*            IF ls_sum_open-amountintransactioncurrency < 0.
*              ls_sum_open-amountintransactioncurrency = ls_sum_open-amountintransactioncurrency * -1.
*            ENDIF.
*            READ TABLE lt_open_balances ASSIGNING FIELD-SYMBOL(<fs_open>) WITH KEY bp = ls_sum_open-supplier
*                                                                                   glaccount = ls_sum_open-glaccount
*                                                                                   transactioncurrency = 'USD'.
*            IF sy-subrc = 0.
*              <fs_open>-open_debit_tran = <fs_open>-open_debit_tran + ls_sum_open-amountintransactioncurrency.
*              <fs_open>-transactioncurrency = ls_sum_open-transactioncurrency.
*            ELSE.
*              READ TABLE lt_open_balances ASSIGNING FIELD-SYMBOL(<fs_open_vnd>) WITH KEY bp = ls_sum_open-supplier
*                                                                                     glaccount = ls_sum_open-glaccount
*                                                                                     transactioncurrency = 'VND'.
*              IF sy-subrc = 0.
*                <fs_open_vnd>-open_debit_tran = <fs_open_vnd>-open_debit_tran + ls_sum_open-amountintransactioncurrency.
*                <fs_open_vnd>-transactioncurrency = ls_sum_open-transactioncurrency.
*                <fs_open_vnd>-thanhtoannt = 'X'.
*              ENDIF.
*            ENDIF.
*            ls_thanhtoannt-open_debit_tran = ls_sum_open-amountintransactioncurrency.
*            ls_thanhtoannt-transactioncurrency = ls_sum_open-transactioncurrency.
*            MODIFY lt_thanhtoannt FROM ls_thanhtoannt INDEX lw_index.
*          ENDIF.
*        ENDIF.
*      ENDLOOP.
*    ENDIF.
********************************************************************


    " 4. Fetch supplier details
    SELECT supplier AS bp,
           suppliername AS bp_name,
           businesspartnername1 AS bp_name_1,
           businesspartnername2 AS bp_name_2,
           businesspartnername3 AS bp_name_3,
           businesspartnername4 AS bp_name_4
      FROM i_supplier
      WHERE supplier IN @lr_partner
      INTO TABLE @DATA(lt_suppliers).
    SORT lt_suppliers BY bp.

    SELECT b~businesspartner AS bp,
           b~businesspartnergrouping AS bp_gr,
           t~businesspartnergroupingtext AS bp_gr_title
      FROM i_businesspartner AS b
      LEFT OUTER JOIN i_businesspartnergroupingtext AS t
        ON t~businesspartnergrouping = b~businesspartnergrouping
        AND t~language = @sy-langu
      WHERE b~businesspartner IN @lr_partner
        AND b~businesspartnergrouping IN @lr_bpgroup
      INTO TABLE @DATA(lt_bp_groups).
    SORT lt_bp_groups BY bp.

    DATA(lo_common_app) = zcl_jp_common_core=>get_instance( ).

    " 5. Build result table
    LOOP AT lt_items INTO DATA(ls_item).
      DATA(ls_result) = VALUE zc_accpay_summary(
          companyname         = ls_companycode_info-companycodename
          companyaddr         = ls_companycode_info-companycodeaddr
          rbukrs              = ls_item-rbukrs
          bp                  = ls_item-bp
          rhcur               = ls_item-rhcur
          companycodecurrency = ls_item-companycodecurrency
          accountnumber       = ls_item-accountnumber
          total_debit         = ls_item-total_debit
          total_credit        = ls_item-total_credit
          total_debit_tran    = ls_item-total_debit_tran
          total_credit_tran   = ls_item-total_credit_tran
          p_start_date        = lv_start_date
          p_end_date          = lv_end_date
          thanhtoannt         = ls_item-thanhtoannt
      ).

      " Assign open balances
      READ TABLE lr_currency INTO DATA(ls_currency) INDEX 1.
      READ TABLE lt_open_balances INTO DATA(ls_open) WITH KEY rbukrs = ls_item-rbukrs
                                                              bp = ls_item-bp
                                                              glaccount = ls_item-accountnumber
                                                              transactioncurrency = ls_item-rhcur
                                                              companycodecurrency = ls_item-companycodecurrency
                                                              BINARY SEARCH.
      IF sy-subrc = 0.
        DATA(lv_index) = sy-tabix.

        ls_result-open_debit = ls_open-open_debit.
        ls_result-open_credit = ls_open-open_credit.
        ls_result-open_debit_tran = ls_open-open_debit_tran.
        ls_result-open_credit_tran = ls_open-open_credit_tran.
        IF ls_result-thanhtoannt IS INITIAL AND ls_open-thanhtoannt IS NOT INITIAL.
          ls_result-thanhtoannt = ls_open-thanhtoannt.
        ENDIF.
        DELETE lt_open_balances INDEX lv_index.
      ENDIF.

      " Assign end balances
*      READ TABLE lt_end_balances INTO DATA(ls_end) WITH KEY bp = ls_item-bp rbukrs = ls_item-rbukrs BINARY SEARCH.
*      IF sy-subrc = 0.
*        ls_result-end_debit = ls_end-end_debit.
*        ls_result-end_credit = ls_end-end_credit.
*      ENDIF.

      " Assign supplier name
      READ TABLE lt_suppliers INTO DATA(ls_supplier) WITH KEY bp = ls_item-bp BINARY SEARCH.
*      IF sy-subrc = 0.
*        ls_result-bp_name = |{ ls_supplier-bp_name_1 }{ ls_supplier-bp_name_2 }{ ls_supplier-bp_name_3 }{ ls_supplier-bp_name_4 }|.
*      ENDIF.

      DATA: ls_businesspartner_details TYPE zst_document_info.

      ls_businesspartner_details-supplier = ls_result-bp.
      ls_businesspartner_details-companycode = ls_result-rbukrs.

      lo_common_app->get_businesspartner_details(
        EXPORTING
          i_document  = ls_businesspartner_details
        IMPORTING
          o_bpdetails = DATA(ls_bp_details)
      ).

      ls_result-bp_name = ls_bp_details-bpname.

      " Assign business partner group and title
      READ TABLE lt_bp_groups INTO DATA(ls_bp_group) WITH KEY bp = ls_item-bp BINARY SEARCH.
      IF sy-subrc = 0.
        ls_result-bp_gr = ls_bp_group-bp_gr.
        ls_result-bp_gr_title = ls_bp_group-bp_gr_title.
      ENDIF.

      APPEND ls_result TO lt_result.
      CLEAR ls_result.
    ENDLOOP.

    IF lv_bpgroup_prov = abap_true.
      DELETE lt_result WHERE bp_gr IS INITIAL.
    ENDIF.

    DATA: lv_open_amount TYPE zc_accpay_summary-open_debit,
          lv_end_amount  TYPE zc_accpay_summary-end_debit.

    LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<fs_result>).
      lv_open_amount = <fs_result>-open_credit + <fs_result>-open_debit.
      IF lv_open_amount >= 0.
        CLEAR <fs_result>-open_credit.
        <fs_result>-open_debit = lv_open_amount.
      ELSE.
        CLEAR <fs_result>-open_debit.
        <fs_result>-open_credit = lv_open_amount.
      ENDIF.
      CLEAR lv_open_amount.
      lv_end_amount = <fs_result>-open_credit + <fs_result>-open_debit
                      + <fs_result>-total_credit + <fs_result>-total_debit.
      IF lv_end_amount >= 0.
        CLEAR <fs_result>-end_credit.
        <fs_result>-end_debit = lv_end_amount.
      ELSE.
        CLEAR <fs_result>-end_debit.
        <fs_result>-end_credit = lv_end_amount.
      ENDIF.
      CLEAR lv_end_amount.
      " transaction currency amounts
      lv_open_amount = <fs_result>-open_credit_tran + <fs_result>-open_debit_tran.
      IF lv_open_amount >= 0.
        CLEAR <fs_result>-open_credit_tran.
        <fs_result>-open_debit_tran = lv_open_amount.
      ELSE.
        CLEAR <fs_result>-open_debit_tran.
        <fs_result>-open_credit_tran = lv_open_amount.
      ENDIF.
      CLEAR lv_open_amount.
      lv_end_amount = <fs_result>-open_credit_tran + <fs_result>-open_debit_tran
                      + <fs_result>-total_credit_tran + <fs_result>-total_debit_tran.
      IF lv_end_amount >= 0.
        CLEAR <fs_result>-end_credit_tran.
        <fs_result>-end_debit_tran = lv_end_amount.
      ELSE.
        CLEAR <fs_result>-end_debit_tran.
        <fs_result>-end_credit_tran = lv_end_amount.
      ENDIF.
      CLEAR lv_end_amount.
    ENDLOOP.

    " Thêm để lấy không có phát sinh
    LOOP AT lt_open_balances  INTO DATA(ls_ko_phat_sinh).

      ls_result-companyname         = ls_companycode_info-companycodename.
      ls_result-companyaddr         = ls_companycode_info-companycodeaddr.

      ls_result-rhcur               = ls_ko_phat_sinh-transactioncurrency.
      ls_result-companycodecurrency = ls_ko_phat_sinh-companycodecurrency.

      ls_result-bp = ls_ko_phat_sinh-bp.

*      READ TABLE lt_suppliers INTO ls_supplier WITH KEY bp = ls_result-bp BINARY SEARCH.
*      IF sy-subrc = 0.
*        ls_result-bp_name = ls_supplier-bp_name.
*      ENDIF.

      " Assign business partner group and title
      READ TABLE lt_bp_groups INTO ls_bp_group WITH KEY bp = ls_result-bp BINARY SEARCH.
      IF sy-subrc = 0.
        ls_result-bp_gr = ls_bp_group-bp_gr.
        ls_result-bp_gr_title = ls_bp_group-bp_gr_title.
      ENDIF.
      ls_result-thanhtoannt = ls_ko_phat_sinh-thanhtoannt.
      ls_result-rbukrs = ls_ko_phat_sinh-rbukrs.
      ls_result-accountnumber = ls_ko_phat_sinh-glaccount.
      ls_result-open_debit = ls_ko_phat_sinh-open_debit.
      ls_result-open_credit = ls_ko_phat_sinh-open_credit.
      ls_result-open_debit_tran = ls_ko_phat_sinh-open_debit_tran.
      ls_result-open_credit_tran = ls_ko_phat_sinh-open_credit_tran.

      ls_result-end_debit = ls_ko_phat_sinh-open_debit.
      ls_result-end_credit = ls_ko_phat_sinh-open_credit.
      ls_result-end_debit_tran = ls_ko_phat_sinh-open_debit_tran.
      ls_result-end_credit_tran = ls_ko_phat_sinh-open_credit_tran.

      CLEAR: ls_businesspartner_details, ls_bp_details.

      ls_businesspartner_details-supplier = ls_result-bp.
      ls_businesspartner_details-companycode = ls_result-rbukrs.

      lo_common_app->get_businesspartner_details(
        EXPORTING
          i_document  = ls_businesspartner_details
        IMPORTING
          o_bpdetails = ls_bp_details
      ).

      ls_result-bp_name = ls_bp_details-bpname.

      ls_result-p_start_date = lv_start_date.
      ls_result-p_end_date = lv_end_date.

      APPEND ls_result TO lt_result.
      CLEAR: ls_result, ls_supplier, ls_bp_group.
    ENDLOOP.

    " 5. Change sign for all balance amounts
    LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<lfs_temp>).
      <lfs_temp>-open_credit = abs( <lfs_temp>-open_credit ).
      <lfs_temp>-total_credit = <lfs_temp>-total_credit * -1.
      <lfs_temp>-end_credit = abs( <lfs_temp>-end_credit ).
      " Transaction currency amounts
      <lfs_temp>-open_credit_tran = abs( <lfs_temp>-open_credit_tran ).
      <lfs_temp>-total_credit_tran = <lfs_temp>-total_credit_tran * -1.
      <lfs_temp>-end_credit_tran = abs( <lfs_temp>-end_credit_tran ).
    ENDLOOP.

    " Remove amount if tran currency = 'VND'
    LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<fs_final>).
      IF ( <fs_final>-rhcur = 'VND' AND <fs_final>-thanhtoannt NE 'X') OR ls_curr-low = 'VND'. " Xoá đoạn này và đổi tiền ở đây
        CLEAR:
        <fs_final>-open_credit_tran,
        <fs_final>-open_debit_tran,
        <fs_final>-end_credit_tran,
        <fs_final>-end_debit_tran,
        <fs_final>-total_credit_tran,
        <fs_final>-total_debit_tran.
      ENDIF.
      IF <fs_final>-rhcur = 'VND' AND <fs_final>-thanhtoannt = 'X'.
        <fs_final>-rhcur = 'USD'.
      ENDIF.
    ENDLOOP.

***bổ sung logic lấy thêm từ chức năng đánh giá chênh lệch tỷ giá***
    " lấy sinh dư đầu kỳ
    FREE: lt_where_clauses_open.

    APPEND | account IN @lr_partner| TO lt_where_clauses_open.
    APPEND |AND keydate < @lv_start_date| TO lt_where_clauses_open.
    APPEND |AND ccode IN @lr_companycode| TO lt_where_clauses_open.
    APPEND |AND account IS NOT NULL| TO lt_where_clauses_open.
    APPEND |AND debcred_ind IN ('S', 'H')| TO lt_where_clauses_open.
    APPEND |AND gl_account IN @lr_account| TO lt_where_clauses_open.
    APPEND |AND gl_account NOT LIKE '341%'| TO lt_where_clauses_open.

    IF lr_currency IS NOT INITIAL AND ls_curr-low NE 'VND'.
      APPEND |AND currency IN @lr_currency| TO lt_where_clauses_open.
    ENDIF.

    SELECT account AS bp,
           ccode AS rbukrs,
           debcred_ind,
           SUM( CASE WHEN debcred_ind = 'S' THEN posting_amount ELSE 0 END ) AS open_debit_faglfcv,
           SUM( CASE WHEN debcred_ind = 'H' THEN posting_amount ELSE 0 END ) AS open_credit_faglfcv,
           gl_account
      FROM zui_in_faglfcv
      WHERE (lt_where_clauses_open)
      GROUP BY account, ccode, debcred_ind, gl_account
      INTO TABLE @DATA(lt_open_balances_faglfcv).
    SORT lt_open_balances_faglfcv BY rbukrs bp gl_account ASCENDING.

    " lấy sinh trong kỳ
    FREE: lt_where_clauses_open.

    APPEND | account IN @lr_partner| TO lt_where_clauses_open.
    APPEND |AND keydate BETWEEN '{ lv_start_date }' AND '{ lv_end_date }'| TO lt_where_clauses_open.
    APPEND |AND ccode IN @lr_companycode| TO lt_where_clauses_open.
    APPEND |AND account IS NOT NULL| TO lt_where_clauses_open.
    APPEND |AND debcred_ind IN ('S', 'H')| TO lt_where_clauses_open.
    APPEND |AND gl_account IN @lr_account| TO lt_where_clauses_open.
    APPEND |AND gl_account NOT LIKE '341%'| TO lt_where_clauses_open.

    IF lr_currency IS NOT INITIAL AND ls_curr-low NE 'VND'.
      APPEND |AND currency IN @lr_currency| TO lt_where_clauses_open.
    ENDIF.

    SELECT account AS bp,
           ccode AS rbukrs,
           debcred_ind,
           SUM( CASE WHEN debcred_ind = 'S' THEN posting_amount ELSE 0 END ) AS total_debit_faglfcv,
           SUM( CASE WHEN debcred_ind = 'H' THEN posting_amount ELSE 0 END ) AS total_credit_faglfcv,
           currency,
           target_currency,
           gl_account
      FROM zui_in_faglfcv
      WHERE (lt_where_clauses_open)
      GROUP BY account, ccode, debcred_ind, currency, target_currency, gl_account
      INTO TABLE @DATA(lt_total_faglfcv).
    SORT lt_total_faglfcv BY rbukrs bp gl_account ASCENDING.

    SELECT account AS bp,
           ccode AS rbukrs,
           debcred_ind,
           posting_amount,
           currency,
           target_currency,
           gl_account
      FROM zui_in_faglfcv
      WHERE (lt_where_clauses_open)
      INTO TABLE @DATA(lt_total_faglfcv_2).
    SORT lt_total_faglfcv BY rbukrs bp gl_account ASCENDING.
********************************************************************

    DATA: lt_result_temp LIKE lt_result,
          ls_result_temp LIKE LINE OF lt_result_temp.

    LOOP AT lt_result INTO DATA(lg_result_gom)
    GROUP BY (
        companycode = lg_result_gom-rbukrs
        glaccount = lg_result_gom-accountnumber
        supplier =  lg_result_gom-bp
        companycodecurrency = lg_result_gom-companycodecurrency
    ) ASSIGNING FIELD-SYMBOL(<group_gom>).
      ls_result_temp-rbukrs = <group_gom>-companycode.
      ls_result_temp-bp = <group_gom>-supplier.
      ls_result_temp-accountnumber = <group_gom>-glaccount.
      ls_result_temp-companycodecurrency = <group_gom>-companycodecurrency .
*      ls_result_temp-rhcur = <group_gom>-transactioncurrency.

      LOOP AT lt_result INTO ls_result WHERE rbukrs = <group_gom>-companycode
                                       AND bp = <group_gom>-supplier
                                       AND accountnumber = <group_gom>-glaccount.

        ls_result_temp-bp_gr = ls_result-bp_gr.
        ls_result_temp-companyname = ls_result-companyname.
        ls_result_temp-companyaddr = ls_result-companyaddr.

        IF ls_result_temp-rhcur IS INITIAL AND ls_result-rhcur NE 'VND'.
          ls_result_temp-rhcur = ls_result-rhcur.
        ENDIF.

        ls_result_temp-bp_gr_title = ls_result-bp_gr_title.
        ls_result_temp-bp_name = ls_result-bp_name.

        ls_result_temp-open_debit = ls_result_temp-open_debit + ls_result-open_debit.
        ls_result_temp-open_debit_tran = ls_result_temp-open_debit_tran + ls_result-open_debit_tran.
        ls_result_temp-open_credit = ls_result_temp-open_credit + ls_result-open_credit.
        ls_result_temp-open_credit_tran = ls_result_temp-open_credit_tran + ls_result-open_credit_tran.

        ls_result_temp-total_debit = ls_result_temp-total_debit + ls_result-total_debit.
        ls_result_temp-total_debit_tran = ls_result_temp-total_debit_tran + ls_result-total_debit_tran.
        ls_result_temp-total_credit = ls_result_temp-total_credit + ls_result-total_credit.
        ls_result_temp-total_credit_tran = ls_result_temp-total_credit_tran + ls_result-total_credit_tran.

        ls_result_temp-end_debit = ls_result_temp-end_debit + ls_result-end_debit.
        ls_result_temp-end_debit_tran = ls_result_temp-end_debit_tran + ls_result-end_debit_tran.
        ls_result_temp-end_credit = ls_result_temp-end_credit + ls_result-end_credit.
        ls_result_temp-end_credit_tran = ls_result_temp-end_credit_tran + ls_result-end_credit_tran.

        ls_result_temp-p_start_date = ls_result-p_start_date.
        ls_result_temp-p_end_date = ls_result-p_end_date.

        CLEAR ls_result.
      ENDLOOP.

      DATA lv_chenh_lech TYPE zc_accrec_summary-open_credit.
      DATA lv_chenh_lech_total TYPE zc_accrec_summary-open_credit.

      READ TABLE lt_open_balances_faglfcv INTO DATA(ls_open_balances_faglfcv) WITH KEY rbukrs = <group_gom>-companycode
                                                                                       bp = <group_gom>-supplier
                                                                                       gl_account = <group_gom>-glaccount.

      IF ls_open_balances_faglfcv IS NOT INITIAL.
        lv_chenh_lech = ls_open_balances_faglfcv-open_credit_faglfcv + ls_open_balances_faglfcv-open_debit_faglfcv.
      ENDIF.

      READ TABLE lt_total_faglfcv INTO DATA(ls_total_faglfcv) WITH KEY rbukrs = <group_gom>-companycode
                                                                       bp = <group_gom>-supplier
                                                                       gl_account = <group_gom>-glaccount.

      CLEAR: ls_total_faglfcv-total_credit_faglfcv, ls_total_faglfcv-total_debit_faglfcv.

      LOOP AT lt_total_faglfcv_2 INTO DATA(ls_total_faglfcv_2) WHERE rbukrs = <group_gom>-companycode
                                                                 AND bp = <group_gom>-supplier
                                                                 AND gl_account = <group_gom>-glaccount.

        IF ls_total_faglfcv_2-posting_amount > 0.
          ls_total_faglfcv-total_debit_faglfcv = ls_total_faglfcv-total_debit_faglfcv + ls_total_faglfcv_2-posting_amount.
        ELSE.
          ls_total_faglfcv-total_credit_faglfcv = ls_total_faglfcv-total_credit_faglfcv + ls_total_faglfcv_2-posting_amount.
        ENDIF.
      ENDLOOP.

      IF ls_total_faglfcv IS NOT INITIAL.
        lv_chenh_lech_total = ls_total_faglfcv-total_credit_faglfcv + ls_total_faglfcv-total_debit_faglfcv.
      ENDIF.

      " tính dư đầu kỳ theo company code thêm chênh lệch
      IF ( ls_result_temp-open_credit - ls_result_temp-open_debit - lv_chenh_lech ) > 0.
        ls_result_temp-open_credit = ls_result_temp-open_credit - ls_result_temp-open_debit - lv_chenh_lech.
        ls_result_temp-open_debit = 0.
      ELSEIF ( ls_result_temp-open_credit - ls_result_temp-open_debit - lv_chenh_lech ) < 0.
        ls_result_temp-open_debit = abs( ls_result_temp-open_credit - ls_result_temp-open_debit - lv_chenh_lech ).
        ls_result_temp-open_credit = 0.
      ELSEIF ( ls_result_temp-open_credit - ls_result_temp-open_debit - lv_chenh_lech ) = 0.
        ls_result_temp-open_debit = 0.
        ls_result_temp-open_credit = 0.
      ENDIF.

      " tính dư đầu kỳ theo transaction currency
      IF ( ls_result_temp-open_credit_tran - ls_result_temp-open_debit_tran ) > 0.
        ls_result_temp-open_credit_tran = ls_result_temp-open_credit_tran - ls_result_temp-open_debit_tran.
        ls_result_temp-open_debit_tran = 0.
      ELSEIF ( ls_result_temp-open_credit_tran - ls_result_temp-open_debit_tran ) < 0.
        ls_result_temp-open_debit_tran = abs( ls_result_temp-open_credit_tran - ls_result_temp-open_debit_tran ).
        ls_result_temp-open_credit_tran = 0.
      ELSEIF ( ls_result_temp-open_credit_tran - ls_result_temp-open_debit_tran ) = 0.
        ls_result_temp-open_debit_tran = 0.
        ls_result_temp-open_credit_tran = 0.
      ENDIF.

      " tính tổng phát sinh trong kỳ thêm chênh lệch
      ls_result_temp-total_debit = abs( ls_result_temp-total_debit + ls_total_faglfcv-total_debit_faglfcv ).
      ls_result_temp-total_credit = abs( ls_result_temp-total_credit - ls_total_faglfcv-total_credit_faglfcv ).

      " tính cuối kỳ theo company currency thêm chênh lệch
      IF ( ls_result_temp-end_credit - ls_result_temp-end_debit - lv_chenh_lech - lv_chenh_lech_total ) > 0.
        ls_result_temp-end_credit = ls_result_temp-end_credit - ls_result_temp-end_debit - lv_chenh_lech - lv_chenh_lech_total.
        ls_result_temp-end_debit = 0.
      ELSEIF ( ls_result_temp-end_credit - ls_result_temp-end_debit - lv_chenh_lech - lv_chenh_lech_total ) < 0.
        ls_result_temp-end_debit = abs( ls_result_temp-end_credit - ls_result_temp-end_debit - lv_chenh_lech - lv_chenh_lech_total ).
        ls_result_temp-end_credit = 0.
      ELSEIF ( ls_result_temp-end_credit - ls_result_temp-end_debit - lv_chenh_lech - lv_chenh_lech_total ) = 0.
        ls_result_temp-end_debit = 0.
        ls_result_temp-end_credit = 0.
      ENDIF.

      " tính cuối kỳ theo transaction currency
      IF ( ls_result_temp-end_credit_tran - ls_result_temp-end_debit_tran ) > 0.
        ls_result_temp-end_credit_tran = ls_result_temp-end_credit_tran - ls_result_temp-end_debit_tran.
        ls_result_temp-end_debit_tran = 0.
      ELSEIF ( ls_result_temp-end_credit_tran - ls_result_temp-end_debit_tran ) < 0.
        ls_result_temp-end_debit_tran = abs( ls_result_temp-end_credit_tran - ls_result_temp-end_debit_tran ).
        ls_result_temp-end_credit_tran = 0.
      ELSEIF ( ls_result_temp-end_credit_tran - ls_result_temp-end_debit_tran ) = 0.
        ls_result_temp-end_debit_tran = 0.
        ls_result_temp-end_credit_tran = 0.
      ENDIF.

      IF ls_result_temp-rhcur IS INITIAL.
        ls_result_temp-rhcur = 'VND'.
      ENDIF.

      APPEND ls_result_temp TO lt_result_temp.
      CLEAR: ls_result_temp.
    ENDLOOP.

    lt_result = CORRESPONDING #( lt_result_temp ).

    SORT lt_result BY bp accountnumber ASCENDING.
    " 6. Apply sorting
    DATA(sort_order) = VALUE abap_sortorder_tab(
      FOR sort_element IN io_request->get_sort_elements( )
                          ( name = sort_element-element_name descending = sort_element-descending ) ).
    IF sort_order IS NOT INITIAL.
      SORT lt_result BY (sort_order).
    ENDIF.

    " 7. Apply paging
    DATA(lv_total_records) = lines( lt_result ).

    DATA(lo_paging) = io_request->get_paging( ).
    IF lo_paging IS BOUND.
      DATA(top) = lo_paging->get_page_size( ).
      IF top < 0. " -1 means all records
        top = lv_total_records.
      ENDIF.
      DATA(skip) = lo_paging->get_offset( ).

      IF skip >= lv_total_records.
        CLEAR lt_result. " Offset is beyond the total number of records
      ELSEIF top = 0.
        CLEAR lt_result. " No records requested
      ELSE.
        " Calculate the actual range to keep
        DATA(lv_start_index) = skip + 1. " ABAP uses 1-based indexing
        DATA(lv_end_index) = skip + top.

        " Ensure end index doesn't exceed table size
        IF lv_end_index > lv_total_records.
          lv_end_index = lv_total_records.
        ENDIF.

        " Create a new table with only the required records
        DATA: lt_paged_result LIKE lt_result.
        CLEAR lt_paged_result.

        " Copy only the required records
        CLEAR lv_index.
        lv_index = lv_start_index.
        WHILE lv_index <= lv_end_index.
          APPEND lt_result[ lv_index ] TO lt_paged_result.
          lv_index = lv_index + 1.
        ENDWHILE.

        lt_result = lt_paged_result.
      ENDIF.
    ENDIF.
    " 6. Set response
    IF io_request->is_data_requested( ).
      io_response->set_data( lt_result ).
    ENDIF.
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
