SELECT DISTINCT
    y.vendor_name,
    y.vendor_name_alt,
    y.vendor_num,
    y.vendor_id,
    nvl((
        SELECT
            hcp.email_address
        FROM
            hz_relationships  hr, hz_contact_points hcp, ap_suppliers      ass
        WHERE
                1 = 1
            AND ass.vendor_id = :p_vendor_id
            AND hr.subject_type = 'ORGANIZATION'
            AND hr.relationship_code = 'CONTACT'
            AND hr.status = 'A'
            AND hcp.owner_table_name = 'HZ_PARTIES'
            AND hr.subject_id = ass.party_id
            AND ROWNUM = 1
            AND hcp.owner_table_id = hr.party_id
            AND hcp.primary_flag = 'Y'
            AND hcp.status = 'A'
            AND hcp.contact_point_type = 'EMAIL'
    ),(
        SELECT
            hcp.email_address
        FROM
            hz_party_sites    hps, hz_contact_points hcp,
            ap_suppliers      ass
        WHERE
                1 = 1
            AND ass.vendor_id = :p_vendor_id
            AND hcp.owner_table_name = 'HZ_PARTY_SITES'
            AND ROWNUM = 1
            AND hps.party_id = ass.party_id
            AND hcp.owner_table_id = hps.party_site_id
            AND hcp.contact_point_type = 'EMAIL'
    ))                           email,
    y.vendor_id                  ven_id,
    y.vendor_site_code,
    y.vendor_site_id,
    y.vendor_site_id             vend_site_id,
    y.vendor_site_code_alt,
    y.vat_registration_num,
    y.operating_unit,
    y.org_id,
    y.po_num,
    y.org_id                     orga_id,
    y.period_name,
    y.document_type,
    y.document_number,
    y.invoice_id,
    y.document_date,
    y.doc_status,
    y.due_date,
    y.description,
    y.invoice_currency_code,
    y.invoice_amount,
    y.accounted_cr,
    y.accounted_dr,
    y.doc_type,
    y.period_year,
    y.period_num,
    nvl((y.wht_amount * - 1), 0) wht_amount
FROM
    (
        SELECT DISTINCT
            aps.vendor_name,
            aps.vendor_name_alt,
            aps.segment1                                   vendor_num,
            aps.vendor_id,
            apss.vendor_site_code,
            apss.vendor_site_id,
            apss.vendor_site_code_alt,
            aps.vat_registration_num,
            hou.name                                       operating_unit,
            aia.org_id,
            (
                SELECT
                    poh.segment1
                FROM
                    po_headers_all               poh,
                    po_distributions_all         pod,
                    ap_invoice_distributions_all aid
                WHERE
                        poh.po_header_id = pod.po_header_id
                    AND aid.po_distribution_id = pod.po_distribution_id
                    AND aid.invoice_id = aia.invoice_id
                    AND aid.po_distribution_id IS NOT NULL
                    AND ROWNUM = 1
            )                                              po_num,
            gp.period_name,
            alc.displayed_field                            document_type,
            aia.invoice_num                                document_number,
            aia.invoice_id,
            to_char(aia.invoice_date, 'DD-MON-YYYY')       document_date,
            decode(apps.ap_invoices_pkg.get_posting_status(aia.invoice_id),
                   'Y',
                   'Validated/Accounted',
                   'Validated/Not Accounted')              doc_status,
            aps.due_date,
            aia.description,
            aia.invoice_currency_code,
            aia.invoice_amount,
            aia.invoice_amount * nvl(aia.exchange_rate, 1) accounted_cr,
            0                                              accounted_dr,
            'I'                                            doc_type,
            gp.period_year,
            gp.period_num,
            0                                              wht_amount
        FROM
            ap_invoices_all          aia,
            ap_suppliers             aps,
            ap_supplier_sites_all    apss,
            hr_operating_units       hou,
            gl_periods               gp,
            ap_lookup_codes          alc,
            ap_payment_schedules_all aps
        WHERE
                aia.vendor_id = aps.vendor_id
            AND aia.vendor_id = apss.vendor_id
            AND aia.vendor_site_id = apss.vendor_site_id
            AND aps.vendor_id = apss.vendor_id
            AND aia.org_id = hou.organization_id
            AND aia.gl_date BETWEEN gp.start_date AND gp.end_date
            AND gp.adjustment_period_flag = 'N'
            AND aia.invoice_type_lookup_code = alc.lookup_code
            AND aia.invoice_type_lookup_code <> 'PREPAYMENT'
            AND alc.lookup_type = 'INVOICE TYPE'
            AND aia.cancelled_date IS NULL
            AND nvl(aia.cancelled_amount, 0) = 0
            AND aia.invoice_id = aps.invoice_id
            AND aia.set_of_books_id = :p_set_of_books_id
            AND aps.vendor_id = nvl(:p_vendor_id, aps.vendor_id)
            AND trunc(aia.gl_date) BETWEEN TO_DATE(:p_from_date) AND TO_DATE(:p_to_date)
            AND apps.ap_invoices_pkg.get_approval_status(aia.invoice_id, aia.invoice_amount, aia.payment_status_flag, aia.invoice_type_lookup_code
            ) NOT IN ( 'UNAPPROVED', 'NEEDS REAPPROVAL', 'NEVER APPROVED', 'CANCELLED' )

 ---and aia.wfapproval_status in ('MANUALLY APPROVED','NOT REQUIRED','WFAPPROVED')


        UNION
        SELECT DISTINCT
            aps.vendor_name,
            aps.vendor_name_alt,
            aps.segment1                                                          vendor_num,
            aps.vendor_id,
            apss.vendor_site_code,
            apss.vendor_site_id,
            apss.vendor_site_code_alt,
            aps.vat_registration_num,
            hou.name                                                              operating_unit,
            ac.org_id,
            NULL                                                                  po_num,
            gp.period_name,
            alc.displayed_field                                                   document_type,
            to_char(ac.check_number)
            || '/'
            || aia.invoice_num                                                    document_number,
            aia.invoice_id,
            to_char(ac.check_date, 'DD-MON-YYYY')                                 document_date,
            alc1.displayed_field
            || '/'
            || decode(aip.accrual_posted_flag, 'Y', 'Accounted', 'Not Accounted') doc_status,
            aip.accounting_date                                                   due_date,
            ac.description,
            ac.currency_code                                                      invoice_currency_code,
            aip.amount * ( - 1 )                                                  invoice_amount,
            0                                                                     accounted_cr,
            aip.amount * nvl(aip.exchange_rate, 1)                                accounted_dr,
            'P'                                                                   doc_type,
            gp.period_year,
            gp.period_num,
            (
                SELECT
                    SUM(nvl(base_amount, 0))
                FROM
                    ap_invoice_distributions_all
                WHERE
                        invoice_id = aia.invoice_id
                    AND line_type_lookup_code = 'AWT'
            )                                                                     wht_amount
        FROM
            ap_invoices_all         aia,
            ap_invoice_payments_all aip,
            ap_checks_all           ac,
            gl_periods              gp,
            gl_ledgers              gled,
            ap_lookup_codes         alc,
            ap_lookup_codes         alc1,
            ap_suppliers            aps,
            ap_supplier_sites_all   apss,
            hr_operating_units      hou
        WHERE
                aip.check_id = ac.check_id
            AND aip.invoice_id = aia.invoice_id
            AND gled.period_set_name = gp.period_set_name
            AND gled.accounted_period_type = gp.period_type
            AND gp.adjustment_period_flag = 'N'
            AND gled.ledger_id = aip.set_of_books_id
            AND ac.payment_type_flag = alc.lookup_code
            AND alc.lookup_type = 'PAYMENT TYPE'
            AND alc1.lookup_type = 'CHECK STATE'
            AND ac.status_lookup_code = alc1.lookup_code
            AND aip.accounting_date BETWEEN gp.start_date AND gp.end_date
            AND ac.vendor_id = aps.vendor_id
            AND ac.vendor_site_id = apss.vendor_site_id
            AND ac.vendor_id = apss.vendor_id
            AND aps.vendor_id = apss.vendor_id
            AND aia.set_of_books_id = :p_set_of_books_id
            AND ac.org_id = hou.organization_id
            AND ac.status_lookup_code <> 'VOIDED'
            AND aps.vendor_id = nvl(:p_vendor_id, aps.vendor_id)
            AND trunc(aip.accounting_date) BETWEEN TO_DATE(:p_from_date) AND TO_DATE(:p_to_date)
            AND apps.ap_invoices_pkg.get_approval_status(aia.invoice_id, aia.invoice_amount, aia.payment_status_flag, aia.invoice_type_lookup_code
            ) NOT IN ( 'UNAPPROVED', 'NEEDS REAPPROVAL', 'NEVER APPROVED', 'CANCELLED' )

    ---  AND aia.wfapproval_status in ('MANUALLY APPROVED','NOT REQUIRED','WFAPPROVED')
    ) y
ORDER BY
    y.vendor_name,
    y.operating_unit,
    y.period_year,
    y.period_num,
    y.doc_type,
    y.document_date ASC;
