# Credit Card Fraud Detection Dashboard

## 📌 Domain
BFSI (Banking, Financial Services, and Insurance)

## Overview
To monitor credit card transactions and identify fraudulent patterns using KPIs and interactive visuals.
The focus is on identifying when fraud occurs and prioritizing transactions that require immediate review.

## Business Objective
- Detect fraudulent transactions in a highly imbalanced dataset
- Group transactions by risk level to simplify review
- Help analysts focus on the most suspicious activity

## Dataset
- Source: Kaggle – Credit Card Fraud Detection
- Transactions: ~284,000
- Fraud Rate: ~0.17%
- Columns: PCA features (V1–V28), Time, Amount, Class

## Key Metrics
- Total Transactions
- Fraud Transactions
- Fraud Amount
- Fraud Rate %
- High-Risk Transaction Count
- Average Anomaly Score

## Analysis Performed
- Compared fraud vs non-fraud transactions
- Grouped transactions into risk bands (Low to Very High)
- Time-based fraud analysis (Hour / Time-of-day)
- Anomaly score distribution Review
- Checked which features differ most between fraud and non-fraud cases

## Key Insights

- Fraud accounts for only ~0.17% of total transactions, yet these cases consistently show much higher risk scores, confirming that risk-based monitoring is effective even in highly imbalanced data.
- Fraud activity is concentrated during late-night and early-morning hours (approximately 12:00 AM – 5:00 AM), a period where transaction oversight is typically lower.
- A small number of transactions classified as “Very High Risk” contribute a disproportionately large share of total fraud amount, making them the highest-priority cases for immediate review.
- Fraudulent transactions follow clearly different behavior patterns compared to normal transactions, indicating that fraud is driven by identifiable transaction behavior rather than randomness.
- Segmenting transactions by risk level significantly reduces analyst workload by narrowing investigations to a focused, high-impact subset of activity.

## Dashboards
- Executive Fraud Overview
- Fraud Pattern & Driver Analysis
- Transaction Monitoring & Investigation

## Tools & Tech
- Power BI (DAX, data modeling, drill-through)
- SQL (aggregation & validation)
- Excel (data checks)

## Outcome
- Identified the hours of the day and transaction patterns where fraud occurs most often
- Prioritized suspicious transactions that should be reviewed first by analysts
- Built dashboards that can be used daily to track fraud trends and risk levels


## 📷 Dashboard Preview

<table align="center">
  <tr>
    <td align="center">
      <img src="Screenshots/ExecutiveDashboard.png" width="420"><br>
      <strong>Executive Fraud Overview</strong>
    </td>
    <td align="center">
      <img src="Screenshots/FraudpatternDashboard.png" width="420"><br>
      <strong>Fraud Pattern & Driver Analysis</strong>
    </td>
  </tr>
</table>


## PBIX Availability
The PBIX file for this dashboard exceeds GitHub’s file size limits. 
A PDF export and screenshots are provided for review. 
The PBIX file can be shared upon request.



