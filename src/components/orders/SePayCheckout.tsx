import React, { useState } from 'react';

interface SePayCheckoutProps {
  orderId: string;
  amount: number; // Tổng số tiền (VNĐ)
  onSuccess?: () => void;
}

export const SePayCheckout: React.FC<SePayCheckoutProps> = ({ orderId, amount }) => {
  // Cấu hình thông tin tài khoản ngân hàng của bạn
  const BANK_ID = 'BIDV'; // Ví dụ: VCB, MB, Techcombank,...
  const ACCOUNT_NO = '962471364V'; 
  const ACCOUNT_NAME = 'DO NGUYEN TOAN';

  // Nội dung chuyển khoản chuẩn (ví dụ: TEt <orderId>)
  const paymentContent = `TET${orderId}`;

  // Link QR SePay tự động sinh mã QR VietQR chuẩn
  const qrUrl = `https://vietqr.app/img?bank=BIDV&acc=962471364V&template=compact&showinfo=true&holder=DO%20NGUYEN%20TOAN&des=${encodeURIComponent(paymentContent)}`;

  return (
    <div className="max-w-md mx-auto p-6 bg-white rounded-xl text-center">
      <h3 className="text-xl font-bold text-gray-800 mb-2">Thanh toán qua chuyển khoản</h3>
      <div className="flex justify-center mb-4">
        <img src={qrUrl} alt="SePay QR Code" className="w-64 h-64 object-contain rounded-lg border p-2" />
      </div>
    </div>
  );
};