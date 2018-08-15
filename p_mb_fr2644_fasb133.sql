IF NOT EXISTS(SELECT *
              FROM sys.procedures
              WHERE name = N'p_mb_fr2644_fasb133'
                AND schema_id = SCHEMA_ID('dbo'))
  BEGIN
    PRINT N'Creating procedure [dbo].[p_mb_fr2644_fasb133] ...'
    EXEC (N'CREATE PROCEDURE [dbo].[p_mb_fr2644_fasb133] AS RETURN(0)')
    WAITFOR DELAY N'00:00:00.003'
  END
PRINT N'Altering procedure [dbo].[p_mb_fr2644_fasb133]...'
GO

ALTER PROCEDURE [dbo].[p_mb_fr2644_fasb133]
  (@workbook_id d_id = NULL,
   @debug_ind   INT = NULL)
AS
-- ********************************************************************************
-- * Purpose: Loads Hedging relationship, Loans, Leases and hedging Swaps data    *
-- * to populate Line Item 9.a of the FR2644 Report.                              *
-- *                                                                              *
-- * Input  : @workbook_id                                                        *
-- ********************************************************************************

-- Declare error/debug variables
  DECLARE @proc_name sysname -- procedure name
  DECLARE @status INT     -- return status
  DECLARE @error INT     -- saved error context
  DECLARE @rowcount INT     -- saved rowcount context

  -- Initialise error/debug variables
  SELECT @proc_name = OBJECT_NAME(@@PROCID), @status = 0, @error = 0, @rowcount = 0

  -- Declare local variables
  DECLARE @IBF_DBF VARCHAR(6)           -- Allows the user to select IBF or DBF transactions for a given workbook capture
  DECLARE @hierarchy_id int                  -- The hierarchy ID for the active (current) workbook.
  DECLARE @reporting_date datetime             -- Reporting date
  DECLARE @reporting_entity d_entity             -- Identification of the reporting entity

  -- Start actual procedure flow
  SELECT @hierarchy_id =
         (SELECT config_num_value FROM t_mb_sys_configures WHERE config_name = 'ACC_HT_REG_REPORTING_ENTITY_HIERARCHY')
  SELECT @reporting_date = (SELECT reporting_date FROM v_fsc_workbook WHERE workbook_id = @workbook_id)
  SELECT @reporting_entity = (SELECT entity_code FROM v_fsc_workbook WHERE workbook_id = @workbook_id)
  SELECT @IBF_DBF = (SELECT CASE
                              WHEN @reporting_entity = '888001'
                                      THEN 'X'
                              WHEN @reporting_entity IN ('888002', '888004')
                                      THEN 'IBF'
                              WHEN @reporting_entity IN ('888003', '888005', '702000', '688001', '684002')
                                      THEN 'DBF'
                              ELSE 'X' END)


  --Begin Loading Products

  --Load Loans & Deposits

  SELECT DISTINCT [tl].[entity],
                  [tl].[source_system],
                  [tl].[deal_id],
                  [tl].[start_validity_date],
                  [tl].[deal_type],
                  [tl].[deal_subtype],
                  [tl].[measurement_category],
                  [vmc].[avox_customer_nr],
                  [vmc].[avox_customer_shortname],
                  [tl].[purpose],
                  [vmc].[customer_attribute4],
                  [mi].[past_due_date],
                  [mi].[non_accrual_date],
                  [mi].[restructured_date],
                  [mi].[foreclosure_date],
                  [tlae].[is_pledged],
                  [tlae].[next_repricing_date],
                  [tlae].[is_secured],
                  [tlvv].[currency],
                  [tl].[maturity_date],
                  [tl].[reversal_date],
                  [tl].[interest_rate],
                  [tl].[deal_date],
                  [sher2].[parent_code],
                  [vt].[char_cust_element2],
                  [vmc].[customer_nr],
                  [tlp-bf].property_value,
                  CT_AoC_Key         = (CONVERT(VARCHAR,
                                                ISNULL([fp-ct].[property_value], '') + '|' +
                                                ISNULL([fp-ct].[char_cust_element1], '') + '|' +
                                                ISNULL([fp-ct2].[property_value], '') + '|' +
                                                ISNULL([fp-ct2].[char_cust_element1], '') + '|' +
                                                ISNULL([fp-ct3].[property_value], '') + '|' +
                                                ISNULL([fp-ct3].[char_cust_element1], '') + '|' +
                                                ISNULL([fp-ct4].[property_value], '') + '|' +
                                                ISNULL([fp-ct4].[char_cust_element1], '') + '|' +
                                                ISNULL([fp-ct5].[property_value], '') + '|' +
                                                ISNULL([fp-ct5].[char_cust_element1], '') + '|' +
                                                ISNULL([fp-ct6].[property_value], '') + '|' +
                                                ISNULL([fp-ct6].[char_cust_element1], '') + '|' +
                                                ISNULL([fp-ct7].[property_value], '') + '|' +
                                                ISNULL([fp-ct7].[char_cust_element1], '') + '|' +
                                                ISNULL([fp-ct8].[property_value], '') + '|' +
                                                ISNULL([fp-ct8].[char_cust_element1], '') + '|' +
                                                ISNULL([fp-ct9].[property_value], '') + '|' +
                                                ISNULL([fp-ct9].[char_cust_element1], '') + '|' +
                                                ISNULL([fp-ct10].[property_value], '') + '|' +
                                                ISNULL([fp-ct10].[char_cust_element1], ''))
                      ),
                  tlv.amount,
                  tlv.valuation_type,
                  AMORT_COST_USD_Amt = (SUM((dbo.fn_cvt_ccy_amount([en].[char_cust_element1], [tlvv].[currency],
                                                                   [en].[rpt_currency], (CASE
                                                                                           WHEN [tlvv].[valuation_type] LIKE 'AMORT_COST|%'
                                                                                                   THEN [tlvv].[amount]
                                                                                           ELSE '0' END),
                                                                   [sher].[valuation_date], 0, 2)))),
                  AMORT_COST_LCL_Amt = CASE
                                         WHEN [tlvv].[valuation_type] LIKE 'AMORT_COST|%' THEN [tlvv].[amount]
                                         ELSE 0 END
      INTO #temp_fasb133_lodep
  FROM [dbo].[t_entity] [en]
         INNER JOIN [dbo].[t_mb_fr2644_hierarchy] [sher] ON [sher].[child_code] = [en].[entity]
         INNER JOIN [dbo].[t_calendar_detail] [cd] ON [cd].[calendar] = [en].[calendar]
                                                        AND [cd].[date] = @reporting_date
         INNER JOIN [dbo].[t_trn_loan] [tl] ON [tl].[entity] = [en].[entity]
                                                 AND [tl].[start_validity_date] <= [sher].[valuation_date]
                                                 AND [tl].[end_validity_date] >= [sher].[valuation_date]
         INNER JOIN [dbo].[t_trn_loan_valuation] [tlvv] ON [tlvv].[entity] = [tl].[entity]
                                                             AND [tlvv].[deal_id] = [tl].[deal_id]
                                                             AND
                                                           [tlvv].[valuation_date] = [sher].[valuation_date]
                                                             AND
                                                           [tlvv].[valuation_type] LIKE 'AMORT_COST|%'
         INNER JOIN [dbo].[t_valuation_type] [vt] ON [vt].[valuation_type] = [tlvv].[valuation_type]
         LEFT OUTER JOIN [dbo].[t_trn_loan_alm_extension] [tlae] ON [tlae].[entity] = [tlvv].[entity]
                                                                      AND
                                                                    [tlae].[deal_id] = [tlvv].[deal_id]
                                                                      AND
                                                                    [tlae].[valuation_date] = [tlvv].[valuation_date]
         LEFT OUTER JOIN [dbo].[v_mb_customer] [vmc] ON [vmc].[original_customer_nr] = [tl].[customer_nr]
                                                          AND [vmc].[start_validity_date] = sher.valuation_date
                                                          AND [vmc].[end_validity_date] = [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_mb_impairment] [mi] ON [mi].[entity] = [tl].[entity]
                                                           AND [mi].[deal_id] = [tl].[deal_id]
                                                           AND
                                                         [mi].[start_validity_date] <= [sher].[valuation_date]
                                                           AND
                                                         [mi].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_entity_customer_link] [ecl] ON [ecl].[customer_nr] = [tl].[customer_nr]
         LEFT OUTER JOIN [dbo].[t_mb_fr2644_hierarchy] [sher2] ON [sher2].[hierarchy_id] = @hierarchy_id
                                                                    AND [sher2].[child_code] = [ecl].[entity]
                                                                    AND [sher2].[start_validity_date] <=
                                                                        [cd].[closest_past_cob_date]
                                                                    AND
                                                                  [sher2].[end_validity_date] >= [cd].[closest_past_cob_date]
                                                                    AND [sher2].[parent_code] = @reporting_entity
         LEFT OUTER JOIN [dbo].[t_trn_loan_property] [tlp-bf] ON [tlp-bf].[entity] = [tl].[entity]
                                                                   AND
                                                                 [tlp-bf].[deal_id] = [tl].[deal_id]
                                                                   AND
                                                                 [tlp-bf].[start_validity_date] <= [sher].[valuation_date]
                                                                   AND
                                                                 [tlp-bf].[end_validity_date] >= [sher].[valuation_date]
                                                                   AND
                                                                 [tlp-bf].[property_name] = 'IBF_DBF'
         LEFT OUTER JOIN [dbo].[t_mb_account_code_extension] [mace] ON [mace].[entity] = [tlvv].[entity]
                                                                         AND
                                                                       [mace].[account_code] = [vt].[char_cust_element2]
                                                                         AND
                                                                       [mace].[start_validity_date] <= [sher].[valuation_date]
                                                                         AND
                                                                       [mace].[end_validity_date] >= [sher].[valuation_date]
                                                                         AND [mace].[cycle_type] = 1
         LEFT OUTER JOIN [dbo].[t_facility_drawdown] [fd] ON [fd].[entity] = [tl].[entity]
                                                               AND [fd].[object_origin] = 'LODEP'
                                                               AND
                                                             [fd].[object_key_value] = [tl].[deal_id]
                                                               AND
                                                             [fd].[start_validity_date] <= [sher].[valuation_date]
                                                               AND
                                                             [fd].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_facility_property] [fp-ct] ON [fp-ct].[entity] = [fd].[entity]
                                                                  AND
                                                                [fp-ct].[facility_nr] = [fd].[facility_nr]
                                                                  AND
                                                                [fp-ct].[property_name] = 'COLLATERAL_1'
                                                                  AND
                                                                [fp-ct].[start_validity_date] <= [sher].[valuation_date]
                                                                  AND
                                                                [fp-ct].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_facility_property] [fp-ct2] ON [fp-ct2].[entity] = [fd].[entity]
                                                                   AND
                                                                 [fp-ct2].[facility_nr] = [fd].[facility_nr]
                                                                   AND
                                                                 [fp-ct2].[property_name] = 'COLLATERAL_2'
                                                                   AND
                                                                 [fp-ct2].[start_validity_date] <= [sher].[valuation_date]
                                                                   AND
                                                                 [fp-ct2].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_facility_property] [fp-ct3] ON [fp-ct3].[entity] = [fd].[entity]
                                                                   AND
                                                                 [fp-ct3].[facility_nr] = [fd].[facility_nr]
                                                                   AND
                                                                 [fp-ct3].[property_name] = 'COLLATERAL_3'
                                                                   AND
                                                                 [fp-ct3].[start_validity_date] <= [sher].[valuation_date]
                                                                   AND
                                                                 [fp-ct3].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_facility_property] [fp-ct4] ON [fp-ct4].[entity] = [fd].[entity]
                                                                   AND
                                                                 [fp-ct4].[facility_nr] = [fd].[facility_nr]
                                                                   AND
                                                                 [fp-ct4].[property_name] = 'COLLATERAL_4'
                                                                   AND
                                                                 [fp-ct4].[start_validity_date] <= [sher].[valuation_date]
                                                                   AND
                                                                 [fp-ct4].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_facility_property] [fp-ct5] ON [fp-ct5].[entity] = [fd].[entity]
                                                                   AND
                                                                 [fp-ct5].[facility_nr] = [fd].[facility_nr]
                                                                   AND
                                                                 [fp-ct5].[property_name] = 'COLLATERAL_5'
                                                                   AND
                                                                 [fp-ct5].[start_validity_date] <= [sher].[valuation_date]
                                                                   AND
                                                                 [fp-ct5].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_facility_property] [fp-ct6] ON [fp-ct6].[entity] = [fd].[entity]
                                                                   AND
                                                                 [fp-ct6].[facility_nr] = [fd].[facility_nr]
                                                                   AND
                                                                 [fp-ct6].[property_name] = 'COLLATERAL_6'
                                                                   AND
                                                                 [fp-ct6].[start_validity_date] <= [sher].[valuation_date]
                                                                   AND
                                                                 [fp-ct6].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_facility_property] [fp-ct7] ON [fp-ct7].[entity] = [fd].[entity]
                                                                   AND
                                                                 [fp-ct7].[facility_nr] = [fd].[facility_nr]
                                                                   AND
                                                                 [fp-ct7].[property_name] = 'COLLATERAL_7'
                                                                   AND
                                                                 [fp-ct7].[start_validity_date] <= [sher].[valuation_date]
                                                                   AND
                                                                 [fp-ct7].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_facility_property] [fp-ct8] ON [fp-ct8].[entity] = [fd].[entity]
                                                                   AND
                                                                 [fp-ct8].[facility_nr] = [fd].[facility_nr]
                                                                   AND
                                                                 [fp-ct8].[property_name] = 'COLLATERAL_8'
                                                                   AND
                                                                 [fp-ct8].[start_validity_date] <= [sher].[valuation_date]
                                                                   AND
                                                                 [fp-ct8].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_facility_property] [fp-ct9] ON [fp-ct9].[entity] = [fd].[entity]
                                                                   AND
                                                                 [fp-ct9].[facility_nr] = [fd].[facility_nr]
                                                                   AND
                                                                 [fp-ct9].[property_name] = 'COLLATERAL_9'
                                                                   AND
                                                                 [fp-ct9].[start_validity_date] <= [sher].[valuation_date]
                                                                   AND
                                                                 [fp-ct9].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_facility_property] [fp-ct10] ON [fp-ct10].[entity] = [fd].[entity]
                                                                    AND
                                                                  [fp-ct10].[facility_nr] = [fd].[facility_nr]
                                                                    AND
                                                                  [fp-ct10].[property_name] = 'COLLATERAL_10'
                                                                    AND
                                                                  [fp-ct10].[start_validity_date] <= [sher].[valuation_date]
                                                                    AND
                                                                  [fp-ct10].[end_validity_date] >= [sher].[valuation_date]
  WHERE (1 = 1
           AND [sher].[hierarchy_id] = @hierarchy_id
           AND [sher].[parent_code] = @reporting_entity
           AND [sher].[start_validity_date] <= [cd].[closest_past_cob_date]
           AND [sher].[end_validity_date] >= [cd].[closest_past_cob_date]
           AND [mace].[load_from_GL_2900_2644] = '0'
           AND (1 = 1 AND ([tlp-bf].[property_value] = @IBF_DBF
                             OR (([tlp-bf].[property_value] IS NULL
                                    AND @IBF_DBF = 'X')
                                   OR ([tlp-bf].[property_value] IN ('IBF', 'DBF')
                                         AND @IBF_DBF = 'X'))
                             OR (@IBF_DBF = 'IBF'
                                   AND [tlp-bf].[property_value] = 'IBF')
                             OR (@IBF_DBF = 'DBF'
                                   AND [tlp-bf].[property_value] = 'DBF')
                             OR (@IBF_DBF = 'DBF'
                                   AND [tlp-bf].[property_value] IS NULL)
      )
             )
            )


  -- Load Leases

  SELECT DISTINCT [tl].[entity],
                  [tl].[deal_id],
                  [tl].[start_validity_date],
                  [tl].[deal_type],
                  [tl].[deal_subtype],
                  [tl].[source_system],
                  [tl].[measurement_category],
                  [vmc].[avox_customer_nr],
                  [vmc].[avox_customer_shortname],
                  [vmc].[customer_attribute4],
                  [mi].[past_due_date],
                  [mi].[non_accrual_date],
                  [mi].[restructured_date],
                  [mi].[foreclosure_date],
                  [tl].[interest_rate],
                  [vt].[char_cust_element2],
                  [tlv].[currency],
                  [tl].[maturity_date],
                  [tl].[reversal_date],
                  [tl].[deal_date],
                  [tl].[value_date],
                  [tlae].[is_pledged],
                  [tlae].[next_repricing_date],
                  [tlae].[is_secured],
                  [sher2].[parent_code],
                  [tlp-bf].property_value,
                  tlv.amount,
                  tlv.valuation_type,
                  NOM_Amount = SUM((dbo.fn_cvt_ccy_amount([en].[char_cust_element1], [tlv].[currency],
                                                          [en].[rpt_currency], (CASE
                                                                                  WHEN [tlv].[valuation_type] LIKE 'NOM|%'
                                                                                          THEN [tlv].[amount]
                                                                                  ELSE '0' END), sher.valuation_date, 0,
                                                          2))),
                  NOM_A      = tlv.amount
      INTO #temp_fasb133_leases
  FROM [dbo].[t_entity] [en]
         INNER JOIN [dbo].[t_mb_fr2644_hierarchy] [sher] ON [sher].[child_code] = [en].[entity]
         INNER JOIN [dbo].[t_calendar_detail] [cd] ON [cd].[calendar] = [en].[calendar]
                                                        AND [cd].[date] = @reporting_date
         INNER JOIN [dbo].[t_trn_leasing] [tl] ON [tl].[entity] = [en].[entity]
                                                    AND [tl].[start_validity_date] <= [sher].[valuation_date]
                                                    AND [tl].[end_validity_date] >= [sher].[valuation_date]
         INNER JOIN [dbo].[t_trn_leasing_valuation] [tlv] ON [tlv].[entity] = [tl].[entity]
                                                               AND [tlv].[deal_id] = [tl].[deal_id]
                                                               AND
                                                             [tlv].[valuation_date] = [sher].[valuation_date]
                                                               AND
                                                             [tlv].[valuation_type] LIKE 'NOM|%'
         LEFT OUTER JOIN [dbo].[t_trn_leasing_alm_extension] [tlae] ON [tlae].[entity] = [tlv].[entity]
                                                                         AND
                                                                       [tlae].[deal_id] = [tlv].[deal_id]
                                                                         AND
                                                                       [tlae].[valuation_date] = [tlv].[valuation_date]
         INNER JOIN [dbo].[v_mb_customer] [vmc] ON [vmc].[original_customer_nr] = [tl].[customer_nr]
                                                     AND
                                                   [vmc].[start_validity_date] = [sher].[valuation_date]
                                                     AND [vmc].[end_validity_date] = [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_mb_impairment] [mi] ON [mi].[entity] = [tl].[entity]
                                                           AND [mi].[deal_id] = [tl].[deal_id]
                                                           AND
                                                         [mi].[start_validity_date] = [sher].[valuation_date]
                                                           AND
                                                         [mi].[end_validity_date] = [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_entity_customer_link] [ecl] ON [ecl].[customer_nr] = [tl].[customer_nr]
         LEFT OUTER JOIN [dbo].[t_mb_fr2644_hierarchy] [sher2] ON [sher2].[hierarchy_id] = @hierarchy_id
                                                                    AND [sher2].[child_code] = [ecl].[entity]
                                                                    AND [sher2].[start_validity_date] <=
                                                                        [cd].[closest_past_cob_date]
                                                                    AND
                                                                  [sher2].[end_validity_date] >= [cd].[closest_past_cob_date]
                                                                    AND [sher2].[parent_code] = @reporting_entity
         LEFT OUTER JOIN [dbo].[t_trn_leasing_property] [tlp-ct] ON [tlp-ct].[entity] = [tl].[entity]
                                                                      AND
                                                                    [tlp-ct].[deal_id] = [tl].[deal_id]
                                                                      AND
                                                                    [tlp-ct].[start_validity_date] <= [sher].[valuation_date]
                                                                      AND
                                                                    [tlp-ct].[end_validity_date] >= [sher].[valuation_date]
                                                                      AND
                                                                    [tlp-ct].[property_name] = 'COLLATERAL_TYPE'
         LEFT OUTER JOIN [dbo].[t_trn_leasing_property] [tlp-bf] ON [tlp-bf].[entity] = [tl].[entity]
                                                                      AND
                                                                    [tlp-bf].[deal_id] = [tl].[deal_id]
                                                                      AND
                                                                    [tlp-bf].[start_validity_date] <= [sher].[valuation_date]
                                                                      AND
                                                                    [tlp-bf].[end_validity_date] >= [sher].[valuation_date]
                                                                      AND
                                                                    [tlp-bf].[property_name] = 'IBF_DBF'
         INNER JOIN [dbo].[t_valuation_type] [vt] ON [vt].[valuation_type] = [tlv].[valuation_type]
         INNER JOIN [dbo].[t_mb_account_code_extension] [mace] ON [mace].[entity] = [tlv].[entity]
                                                                    AND
                                                                  [mace].[account_code] = [vt].[char_cust_element2]
                                                                    AND
                                                                  [mace].[start_validity_date] <= [sher].[valuation_date]
                                                                    AND
                                                                  [mace].[end_validity_date] >= [sher].[valuation_date]
                                                                    AND [mace].[cycle_type] = 1
  WHERE (1 = 1
           AND [sher].[hierarchy_id] = @hierarchy_id
           AND [sher].[parent_code] = @reporting_entity
           AND [sher].[start_validity_date] <= [cd].[closest_past_cob_date]
           AND [sher].[end_validity_date] >= [cd].[closest_past_cob_date]
           AND (1 = 1 AND ([tlp-bf].[property_value] = @IBF_DBF
                             OR (([tlp-bf].[property_value] IS NULL
                                    AND @IBF_DBF = 'X')
                                   OR ([tlp-bf].[property_value] IN ('IBF', 'DBF')
                                         AND @IBF_DBF = 'X'))
                             OR (@IBF_DBF = 'IBF'
                                   AND [tlp-bf].[property_value] = 'IBF')
                             OR (@IBF_DBF = 'DBF'
                                   AND [tlp-bf].[property_value] = 'DBF')
                             OR (@IBF_DBF = 'DBF'
                                   AND [tlp-bf].[property_value] IS NULL)
      )
             )
           AND [mace].[load_from_GL_2900_2644] = 0
            )


  --Load IR Swaps for Domestic Banking Facility (DBF)

  SELECT DISTINCT [tsil].[entity] AS swap_leg_entity,
                  [tsil].[leg_deal_id],
                  [tsil].[swap_deal_id],
                  [tsi].[start_validity_date],
                  [tsi].[source_system],
                  [tsil].[deal_type],
                  [tsil].[deal_subtype],
                  [tsilv].[currency],
                  [tsi].[measurement_category],
                  [vmc].[avox_customer_nr],
                  [vmc].[avox_customer_shortname],
                  [vmc].[customer_attribute4],
                  [vt].[char_cust_element2],
                  [tsi].[deal_date],
                  [tsi].[value_date],
                  [tsi].[maturity_date],
                  [tsi].[reversal_date],
                  [sher2].[parent_code],
                  [tsi].[entity]  AS swap_entity,
                  [tsilp].property_value,
                  tsilv.amount,
                  tsilv.valuation_type,
                  NOM_Amount    = SUM((dbo.fn_cvt_ccy_amount([en].[char_cust_element1], [tsilv].[currency],
                                                             [en].[rpt_currency], (CASE
                                                                                     WHEN [tsilv].[valuation_type] LIKE 'NOM|%'
                                                                                             THEN [tsilv].[amount]
                                                                                     ELSE '0' END), sher.valuation_date,
                                                             0, 2))),
                  FV_USD_Amount = SUM((dbo.fn_cvt_ccy_amount([en].[char_cust_element1], [tsilv].[currency],
                                                             [en].[rpt_currency], (CASE
                                                                                     WHEN [tsilv].[valuation_type] LIKE 'FAIR_VALUE|%'
                                                                                             THEN [tsilv].[amount]
                                                                                     ELSE '0' END), sher.valuation_date,
                                                             0, 2))),
                  FV_LCL_Amount = CASE
                                    WHEN [tsilv].[valuation_type] LIKE 'FAIR_VALUE|%' THEN [tsilv].[amount]
                                    ELSE 0 END
      INTO #temp_fasb133_swaps
  FROM [dbo].[t_entity] [en]
         INNER JOIN [dbo].[t_mb_fr2644_hierarchy] [sher] ON [sher].[child_code] = [en].[entity]
         INNER JOIN [dbo].[t_calendar_detail] [cd] ON [cd].[calendar] = [en].[calendar]
                                                        AND [cd].[date] = @reporting_date
         INNER JOIN [dbo].[t_trn_swap_ir] [tsi] ON [tsi].[entity] = [en].[entity]
                                                     AND
                                                   [tsi].[start_validity_date] <= [sher].[valuation_date]
                                                     AND [tsi].[end_validity_date] >= [sher].[valuation_date]
         INNER JOIN [dbo].[t_trn_swap_ir_leg] [tsil] ON [tsil].[entity] = [tsi].[entity]
                                                          AND [tsil].[swap_deal_id] = [tsi].[deal_id]
                                                          AND
                                                        [tsil].[start_validity_date] <= [sher].[valuation_date]
                                                          AND
                                                        [tsil].[end_validity_date] >= [sher].[valuation_date]
         INNER JOIN [dbo].[t_trn_swap_ir_leg_valuation] [tsilv] ON [tsilv].[entity] = [tsil].[entity]
                                                                     AND
                                                                   [tsilv].[deal_id] = [tsil].[leg_deal_id]
                                                                     AND
                                                                   [tsilv].[valuation_date] = [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_trn_swap_ir_leg_alm_extension] [tsilae] ON [tsilae].[entity] = [tsilv].[entity]
                                                                               AND
                                                                             [tsilae].[leg_deal_id] = [tsilv].[deal_id]
                                                                               AND
                                                                             [tsilae].[valuation_date] = [tsilv].[valuation_date]
         LEFT OUTER JOIN [dbo].[v_mb_customer] [vmc] ON [vmc].[original_customer_nr] = [tsi].[customer_nr]
                                                          AND [vmc].[start_validity_date] = [sher].[valuation_date]
                                                          AND [vmc].[end_validity_date] = [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_mb_impairment] [mi] ON [mi].[entity] = [tsi].[entity]
                                                           AND [mi].[deal_id] = [tsi].[deal_id]
                                                           AND
                                                         [mi].[start_validity_date] <= [sher].[valuation_date]
                                                           AND
                                                         [mi].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_trn_swap_ir_leg_property] [tsilp] ON [tsilp].[entity] = [tsil].[entity]
                                                                         AND
                                                                       [tsilp].[leg_deal_id] = [tsil].[leg_deal_id]
                                                                         AND
                                                                       [tsilp].[start_validity_date] <= [sher].[valuation_date]
                                                                         AND
                                                                       [tsilp].[end_validity_date] >= [sher].[valuation_date]
         LEFT OUTER JOIN [dbo].[t_entity_customer_link] [ecl] ON [ecl].[customer_nr] = [tsi].[customer_nr]
         LEFT OUTER JOIN [dbo].[t_mb_fr2644_hierarchy] [sher2] ON [sher2].[hierarchy_id] = @hierarchy_id
                                                                    AND [sher2].[child_code] = [ecl].[entity]
                                                                    AND [sher2].[start_validity_date] <=
                                                                        [cd].[closest_past_cob_date]
                                                                    AND
                                                                  [sher2].[end_validity_date] >= [cd].[closest_past_cob_date]
                                                                    AND [sher2].[parent_code] = @reporting_entity
         INNER JOIN [dbo].[t_valuation_type] [vt] ON [vt].[valuation_type] = [tsilv].[valuation_type]
         LEFT OUTER JOIN [dbo].[t_trn_swap_ir_property] [tsip] ON [tsip].[entity] = [tsi].[entity]
                                                                    AND
                                                                  [tsip].[deal_id] = [tsi].[deal_id]
                                                                    AND
                                                                  [tsip].[start_validity_date] <= [sher].[valuation_date]
                                                                    AND
                                                                  [tsip].[end_validity_date] >= [sher].[valuation_date]
                                                                    AND
                                                                  [tsip].[property_name] = 'IBF_DBF'
         INNER JOIN [dbo].[t_mb_account_code_extension] [mace] ON [mace].[entity] = [tsilv].[entity]
                                                                    AND
                                                                  [mace].[account_code] = [vt].[char_cust_element2]
                                                                    AND
                                                                  [mace].[start_validity_date] <= [sher].[valuation_date]
                                                                    AND
                                                                  [mace].[end_validity_date] >= [sher].[valuation_date]
                                                                    AND [mace].[cycle_type] = 1
  WHERE (1 = 1
           AND [sher].[hierarchy_id] = @hierarchy_id
           AND [sher].[parent_code] = @reporting_entity
           AND [sher].[start_validity_date] <= [cd].[closest_past_cob_date]
           AND [sher].[end_validity_date] >= [cd].[closest_past_cob_date]
           AND (1 = 1 AND ([tsilp].[property_value] = @IBF_DBF
                             OR (([tsilp].[property_value] IS NULL
                                    AND @IBF_DBF = 'X')
                                   OR ([tsilp].[property_value] IN ('IBF', 'DBF')
                                         AND @IBF_DBF = 'X'))
                             OR (@IBF_DBF = 'IBF'
                                   AND [tsilp].[property_value] = 'IBF')
                             OR (@IBF_DBF = 'DBF'
                                   AND [tsilp].[property_value] = 'DBF')
                             OR (@IBF_DBF = 'DBF'
                                   AND [tsilp].[property_value] IS NULL)
      )
             ) AND tsilp.property_value = 'DBF' -- Load ONLY IR Swaps that are part of the DBF
            )


  -- Load Hedging Relationships
  -- LODEP

  SELECT DISTINCT entity                  = [#tf133l].[entity],
                  source_system           = [#tf133l].[source_system],
                  deal_id                 = [#tf133l].[deal_id],
                  start_validity_date     = [#tf133l].[start_validity_date],
                  deal_type               = [#tf133l].[deal_type],
                  deal_subtype            = [#tf133l].[deal_subtype],
                  measurement_category    = [#tf133l].[measurement_category],
                  avox_customer_nr        = [#tf133l].[avox_customer_nr],
                  avox_customer_shortname = [#tf133l].[avox_customer_shortname],
                  purpose                 = [#tf133l].[purpose],
                  customer_attribute4     = [#tf133l].[customer_attribute4],
                  past_due_date           = [#tf133l].[past_due_date],
                  non_accrual_date        = [#tf133l].[non_accrual_date],
                  restructured_date       = [#tf133l].[restructured_date],
                  foreclosure_date        = [#tf133l].[foreclosure_date],
                  is_pledged              = [#tf133l].[is_pledged],
                  next_repricing_date     = [#tf133l].[next_repricing_date],
                  is_secured              = [#tf133l].[is_secured],
                  currency                = [#tf133l].[currency],
                  maturity_date           = [#tf133l].[maturity_date],
                  reversal_date           = [#tf133l].[reversal_date],
                  interest_rate           = [#tf133l].[interest_rate],
                  deal_date               = [#tf133l].[deal_date],
                  parent_code             = [#tf133l].[parent_code],
                  char_cust_element2      = [#tf133l].[char_cust_element2],
                  customer_nr             = [#tf133l].[customer_nr],
                  property_value          = [#tf133l].[property_value],
                                            CT_AoC_Key,
                  AMORT_COST_USD_Amt      = (SUM((dbo.fn_cvt_ccy_amount([en].[char_cust_element1], [tlvv].[currency],
                                                                        [en].[rpt_currency], (CASE
                                                                                                WHEN [tlvv].[valuation_type] LIKE 'AMORT_COST|%'
                                                                                                        THEN [tlvv].[amount]
                                                                                                ELSE '0' END),
                                                                        [sher].[valuation_date], 0, 2)))),
                  AMORT_COST_LCL_Amt      = CASE
                                              WHEN [tlvv].[valuation_type] LIKE 'AMORT_COST|%' THEN [tlvv].[amount]
                                              ELSE 0 END,
                                            thr.entity,
                                            thr.hedging_relationship,
                                            thr.num_cust_element1  AS is_effective,
                                            thri.item_object_origin,
                                            thri.item_object_key_value,
                                            #tf133l.property_value AS IBF_DBF
      INTO #temp_fasb133_h_lodep
  FROM [t_entity] [en]
         INNER JOIN [dbo].[t_mb_fr2644_hierarchy] [sher] ON [sher].[child_code] = [en].[entity]
                                                              AND
                                                            sher.start_validity_date <= @reporting_date
                                                              AND
                                                            sher.end_validity_date >= @reporting_date
         INNER JOIN [dbo].[t_calendar_detail] [cd] ON [cd].[calendar] = [en].[calendar]
                                                        AND [cd].[date] = @reporting_date
         LEFT JOIN t_hedging_relationship thr ON thr.entity = en.entity
                                                   AND thr.start_validity_date <= [sher].[valuation_date]
                                                   AND thr.end_validity_date >= [sher].[valuation_date]
         LEFT JOIN t_hedging_relationship_item thri
           ON thri.entity = thr.entity AND thri.hedging_relationship = thr.hedging_relationship
                AND thri.start_validity_date <= [sher].[valuation_date] AND
              thri.end_validity_date >= [sher].[valuation_date]
                AND thri.item_object_origin = 'LODEP'
         LEFT OUTER JOIN #temp_fasb133_lodep #tf133l
           ON #tf133l.entity + '|' + #tf133l.deal_id = thri.item_object_key_value
  WHERE (1 = 1
         -- Load Loans that are either part of an effective hedge, or that are NOT part of a hedge at all.
           AND (thr.num_cust_element1 = '1'
                  OR thri.item_object_key_value IS NULL)
            )


  -- TLEASE

  SELECT DISTINCT entity                  = [#tf133l].[entity],
                  deal_id                 = [#tf133l].[deal_id],
                  start_validity_date     = [#tf133l].[start_validity_date],
                  deal_type               = [#tf133l].[deal_type],
                  deal_subtype            = [#tf133l].[deal_subtype],
                  source_system           = [#tf133l].[source_system],
                  measurement_category    = [#tf133l].[measurement_category],
                  avox_customer_nr        = [#tf133l].[avox_customer_nr],
                  avox_customer_shortname = [#tf133l].[avox_customer_shortname],
                  customer_attribute4     = [#tf133l].[customer_attribute4],
                  past_due_date           = [#tf133l].[past_due_date],
                  non_accrual_date        = [#tf133l].[non_accrual_date],
                  restructured_date       = [#tf133l].[restructured_date],
                  foreclosure_date        = [#tf133l].[foreclosure_date],
                  interest_rate           = [#tf133l].[interest_rate],
                  char_cust_element2      = [#tf133l].[char_cust_element2],
                  currency                = [#tf133l].[currency],
                  maturity_date           = [#tf133l].[maturity_date],
                  reversal_date           = [#tf133l].[reversal_date],
                  deal_date               = [#tf133l].[deal_date],
                  value_date              = [#tf133l].[value_date],
                  is_pledged              = [#tf133l].[is_pledged],
                  next_repricing_date     = [#tf133l].[next_repricing_date],
                  is_secured              = [#tf133l].[is_secured],
                  parent_code             = [#tf133l].[parent_code],
                  property_value          = [#tf133l].[property_value],
                  NOM_Amount              = SUM((dbo.fn_cvt_ccy_amount([en].[char_cust_element1], [#tf133l].[currency],
                                                                       [en].[rpt_currency], (CASE
                                                                                               WHEN [#tf133l].[valuation_type] LIKE 'NOM|%'
                                                                                                       THEN [#tf133l].[amount]
                                                                                               ELSE '0' END),
                                                                       sher.valuation_date, 0,
                                                                       2))),
                  NOM_A                   = #tf133l.amount,
                                            thr.entity,
                                            thr.hedging_relationship,
                                            thr.num_cust_element1  AS is_effective,
                                            thri.item_object_origin,
                                            thri.item_object_key_value,
                                            #tf133l.property_value AS IBF_DBF

      INTO #temp_fasb133_h_lease
  FROM [dbo].[t_entity] [en]
         INNER JOIN [dbo].[t_mb_fr2644_hierarchy] [sher] ON [sher].[child_code] = [en].[entity]
                                                              AND
                                                            sher.start_validity_date <= @reporting_date
                                                              AND
                                                            sher.end_validity_date >= @reporting_date
         INNER JOIN [dbo].[t_calendar_detail] [cd] ON [cd].[calendar] = [en].[calendar]
                                                        AND [cd].[date] = @reporting_date
         LEFT JOIN t_hedging_relationship thr ON thr.entity = en.entity
                                                   AND thr.start_validity_date <= [sher].[valuation_date]
                                                   AND thr.end_validity_date >= [sher].[valuation_date]
         LEFT JOIN t_hedging_relationship_item thri
           ON thri.entity = thr.entity AND thri.hedging_relationship = thr.hedging_relationship
                AND thri.start_validity_date <= [sher].[valuation_date] AND
              thri.end_validity_date >= [sher].[valuation_date]
                AND thri.item_object_origin = 'TLEASE'
         LEFT OUTER JOIN #temp_fasb133_leases #tf133l
           ON #tf133l.entity + '|' + #tf133l.deal_id = thri.item_object_key_value
  WHERE (1 = 1
         -- Load Leases that are either part of an effective hedge, or that are NOT part of a hedge at all.
           AND (thr.num_cust_element1 = '1'
                  OR thri.item_object_key_value IS NULL))




  -- IRSWP

  SELECT DISTINCT (SELECT swap_entity             = [#tf133s].[swap_entity],
                          leg_deal_id             = [#tf133s].[leg_deal_id],
                          swap_deal_id            = [#tf133s].[swap_deal_id],
                          start_validity_date     = [#tf133s].[start_validity_date],
                          source_system           = [#tf133s].[source_system],
                          deal_type               = [#tf133s].[deal_type],
                          deal_subtype            = [#tf133s].[deal_subtype],
                          currency                = [#tf133s].[currency],
                          measurement_category    = [#tf133s].[measurement_category],
                          avox_customer_nr        = [#tf133s].[avox_customer_nr],
                          avox_customer_shortname = [#tf133s].[avox_customer_shortname],
                          customer_attribute4     = [#tf133s].[customer_attribute4],
                          char_cust_element2      = [#tf133s].[char_cust_element2],
                          deal_date               = [#tf133s].[deal_date],
                          value_date              = [#tf133s].[value_date],
                          maturity_date           = [#tf133s].[maturity_date],
                          reversal_date           = [#tf133s].[reversal_date],
                          parent_code             = [#tf133s].[parent_code],
                          swap_leg_entity         = [#tf133s].[swap_leg_entity],
                          property_value          = [#tf133s].[property_value],
                                                    thr.entity,
                                                    thr.hedging_relationship,
                                                    thr.num_cust_element1  AS is_effective,
                                                    thri.item_object_origin,
                                                    thri.item_object_key_value,
                                                    #tf133s.property_value AS IBF_DBF
      INTO #temp_fasb133_h_irswp
                   FROM [dbo].[t_entity] [en]
                          INNER JOIN [dbo].[t_mb_fr2644_hierarchy] [sher] ON [sher].[child_code] = [en].[entity]
                                                                               AND
                                                                             sher.start_validity_date <= @reporting_date
                                                                               AND
                                                                             sher.end_validity_date >= @reporting_date
                          INNER JOIN [dbo].[t_calendar_detail] [cd] ON [cd].[calendar] = [en].[calendar]
                                                                         AND [cd].[date] = @reporting_date
                          LEFT JOIN t_hedging_relationship thr ON thr.entity = en.entity
                                                                    AND
                                                                  thr.start_validity_date <= [sher].[valuation_date]
                                                                    AND thr.end_validity_date >= [sher].[valuation_date]
                          LEFT JOIN t_hedging_relationship_item thri
                            ON thri.entity = thr.entity AND thri.hedging_relationship = thr.hedging_relationship
                                 AND thri.start_validity_date <= [sher].[valuation_date] AND
                               thri.end_validity_date >= [sher].[valuation_date]
                                 AND thri.item_object_origin = 'IRSWP'
                          LEFT OUTER JOIN #temp_fasb133_swaps #tf133s
                            ON #tf133s.swap_entity + '|' + #tf133s.swap_deal_id =
                               thri.item_object_key_value) AS SRC_hedge_irswp



  -- Load IR Swaps that are either part of an IN-effective hedge, or that are NOT part of a hedge at all.
  -- The 3rd condition, effective = 1 AND the hedged Loan is part of the IBF will be handled in a later step



  --Debugging Statements
  IF @debug_ind <> 0
    BEGIN
      --Base TRN Tables
      SELECT * FROM #temp_fasb133_lodep
      SELECT * FROM #temp_fasb133_leases
      SELECT * FROM #temp_fasb133_swaps
      --TRNs as a part of Hedges
      SELECT * FROM #temp_fasb133_h_lodep
      SELECT * FROM #temp_fasb133_h_lease
      SELECT * FROM #temp_fasb133_h_irswp
      --Final Input Location Values
    END
  --

  -- Return success
  RETURN (0)

GO
IF EXISTS(SELECT *
          FROM sys.procedures
          WHERE name = N'p_mb_fr2644_fasb133'
            AND modify_date > create_date
            AND modify_date > DATEADD(s, -1, CURRENT_TIMESTAMP)
            AND schema_id = SCHEMA_ID('dbo'))
  BEGIN
    PRINT N'Procedure [dbo].[] has been altered...'
  END
ELSE BEGIN
  PRINT N'Procedure [dbo].[] has NOT been altered due to errors!'
END
GO
