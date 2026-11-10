import { useEffect, useMemo } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Pencil, Plus, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  useCreateMarket,
  useUpdateMarket,
} from "@/hooks/use-orders";
import {
  marketFormSchema,
  type Market,
  type MarketFormValues,
} from "@/lib/types";

interface MarketFormDialogProps {
  open: boolean;
  market: Market | null;
  onOpenChange: (open: boolean) => void;
}

export function MarketFormDialog({
  open,
  market,
  onOpenChange,
}: MarketFormDialogProps) {
  const createMarket = useCreateMarket();
  const updateMarket = useUpdateMarket();

  const form = useForm<MarketFormValues>({
    resolver: zodResolver(marketFormSchema),
    defaultValues: {
      name: "",
      stall: "",
      phone: "",
      notes: "",
    },
    mode: "onChange",
  });

  const { register, handleSubmit, reset, formState } = form;

  useEffect(() => {
    if (market) {
      reset({
        name: market.name,
        stall: market.stall,
        phone: market.phone,
        notes: market.notes ?? "",
      });
    } else {
      reset({ name: "", stall: "", phone: "", notes: "" });
    }
  }, [market, reset, open]);

  function handleClose() {
    reset({ name: "", stall: "", phone: "", notes: "" });
    onOpenChange(false);
  }

  return (
    <Dialog open={open} onOpenChange={(next) => (next ? undefined : handleClose())}>
      <DialogContent className="max-h-[92vh] w-[calc(100%-1.5rem)] max-w-md overflow-y-auto overflow-x-hidden rounded-2xl border-red-200 p-0 shadow-xl sm:max-w-lg">
        <DialogHeader className="rounded-t-2xl bg-gradient-to-r from-red-700 to-red-800 px-5 py-4 text-white">
          <DialogTitle className="flex items-center gap-2 pr-8 text-base font-bold sm:text-lg">
            <Plus className="size-5 text-amber-300" />
            {market ? "Sửa Thông Tin Mối Chợ" : "Thêm Mối Chợ Mới"}
          </DialogTitle>
          <DialogDescription className="sr-only">
            Nhập thông tin tiểu thương, sạp chợ và số điện thoại.
          </DialogDescription>
        </DialogHeader>

        <form
          onSubmit={handleSubmit((values) => {
            const payload = {
              name: values.name.trim(),
              stall: values.stall.trim(),
              phone: values.phone.trim(),
              notes: values.notes?.trim() ?? "",
            };

            if (market) {
              updateMarket.mutate(
                { id: market.id, payload },
                {
                  onSuccess: () => {
                    toast.success(`Đã cập nhật mối chợ "${payload.name}"`);
                    handleClose();
                  },
                  onError: (error) => toast.error(error.message),
                },
              );
              return;
            }

            createMarket.mutate(payload, {
              onSuccess: () => {
                toast.success(`Đã thêm mối chợ "${payload.name}"`);
                handleClose();
              },
              onError: (error) => toast.error(error.message),
            });
          })}
          className="space-y-4 px-5 py-5"
          noValidate
        >
          <div>
            <Label htmlFor="market-name" className="mb-1 text-xs font-semibold">
              Tên Tiểu Thương <span className="text-red-500">*</span>
            </Label>
            <Input
              id="market-name"
              placeholder="VD: Chị Hương"
              {...register("name")}
            />
            {formState.errors.name && (
              <p className="mt-1 text-xs text-red-600">
                {String(formState.errors.name.message)}
              </p>
            )}
          </div>

          <div>
            <Label htmlFor="market-stall" className="mb-1 text-xs font-semibold">
              Sạp Chợ <span className="text-red-500">*</span>
            </Label>
            <Input
              id="market-stall"
              placeholder="VD: Sạp 12 - Chợ Bến Thành"
              {...register("stall")}
            />
            {formState.errors.stall && (
              <p className="mt-1 text-xs text-red-600">
                {String(formState.errors.stall.message)}
              </p>
            )}
          </div>

          <div>
            <Label htmlFor="market-phone" className="mb-1 text-xs font-semibold">
              Số Điện Thoại <span className="text-red-500">*</span>
            </Label>
            <Input
              id="market-phone"
              type="tel"
              placeholder="0901234567"
              {...register("phone")}
            />
            {formState.errors.phone && (
              <p className="mt-1 text-xs text-red-600">
                {String(formState.errors.phone.message)}
              </p>
            )}
          </div>

          <div>
            <Label htmlFor="market-notes" className="mb-1 text-xs font-semibold">
              Ghi Chú
            </Label>
            <Textarea
              id="market-notes"
              rows={2}
              placeholder="VD: Lấy xe tải lúc 5h sáng, cần bánh đồng đều..."
              {...register("notes")}
            />
          </div>

          <DialogFooter className="-mx-5 -mb-5 mt-6 border-t border-gray-100 bg-gray-50 px-5 py-4">
            <Button type="button" variant="secondary" onClick={handleClose}>
              Hủy Bỏ
            </Button>
            <Button
              type="submit"
              disabled={createMarket.isPending || updateMarket.isPending}
              className="bg-red-700 font-bold text-white hover:bg-red-800"
            >
              {market ? "Lưu Thay Đổi" : "Thêm Mối Chợ"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

interface MarketListProps {
  markets: Market[];
  onEdit: (market: Market) => void;
  onDelete: (market: Market) => void;
  selectedMarketId: string | null;
  onSelect: (marketId: string | null) => void;
}

export function MarketList({
  markets,
  onEdit,
  onDelete,
  selectedMarketId,
  onSelect,
}: MarketListProps) {
  const total = useMemo(() => markets.length, [markets]);

  if (total === 0) {
    return (
      <div className="px-4 py-12 text-center">
        <div className="mx-auto mb-3 flex size-16 items-center justify-center rounded-full bg-red-100 text-3xl">
          🏪
        </div>
        <p className="text-sm font-bold text-gray-700">Chưa có mối chợ nào</p>
        <p className="mt-1 text-xs text-gray-500">
          Bấm "Thêm Mối Chợ" để khai báo tiểu thương bán sỉ.
        </p>
      </div>
    );
  }

  return (
    <ul className="divide-y divide-gray-100">
      {markets.map((market) => {
        const active = selectedMarketId === market.id;
        return (
          <li key={market.id}>
            <div
              className={`flex cursor-pointer items-start justify-between gap-3 px-4 py-3 transition ${
                active ? "bg-red-50" : "hover:bg-gray-50"
              }`}
              onClick={() => onSelect(active ? null : market.id)}
            >
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2">
                  <p className="text-sm font-bold text-gray-900">{market.name}</p>
                  {active && (
                    <Badge className="border-amber-300 bg-amber-100 text-[10px] font-bold text-amber-900">
                      Đang chọn
                    </Badge>
                  )}
                </div>
                <p className="mt-0.5 truncate text-xs text-gray-500">
                  🏪 {market.stall}
                </p>
                <p className="mt-0.5 text-xs font-semibold text-gray-600">
                  ☎ {market.phone}
                </p>
                {market.notes ? (
                  <p className="mt-1 line-clamp-2 text-[11px] italic text-gray-400">
                    {market.notes}
                  </p>
                ) : null}
              </div>
              <div className="flex shrink-0 items-center gap-0.5">
                <Button
                  variant="ghost"
                  size="icon-sm"
                  className="text-amber-600 hover:bg-amber-50"
                  title="Sửa mối chợ"
                  onClick={(event) => {
                    event.stopPropagation();
                    onEdit(market);
                  }}
                >
                  <Pencil className="size-3.5" />
                </Button>
                <Button
                  variant="ghost"
                  size="icon-sm"
                  className="text-red-600 hover:bg-red-50"
                  title="Xoá mối chợ"
                  onClick={(event) => {
                    event.stopPropagation();
                    onDelete(market);
                  }}
                >
                  <Trash2 className="size-3.5" />
                </Button>
              </div>
            </div>
          </li>
        );
      })}
    </ul>
  );
}
