import { useTranslation } from "react-i18next";
import ApiKeyInput from "../ApiKeyInput";
import type { ProviderCategory } from "@/types";

interface ApiKeySectionProps {
  id?: string;
  label?: string;
  value: string;
  onChange: (value: string) => void;
  category?: ProviderCategory;
  shouldShowLink: boolean;
  websiteUrl: string;
  placeholder?: {
    official: string;
    thirdParty: string;
  };
  disabled?: boolean;
  /** @deprecated 合作伙伴标识 - 已隐藏 */
  isPartner?: boolean;
  /** @deprecated 合作伙伴推广码 - 已隐藏 */
  partnerPromotionKey?: string;
}

export function ApiKeySection({
  id,
  label,
  value,
  onChange,
  category,
  shouldShowLink,
  websiteUrl,
  placeholder,
  disabled,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  isPartner: _isPartner,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  partnerPromotionKey: _partnerPromotionKey,
}: ApiKeySectionProps) {
  const { t } = useTranslation();

  const defaultPlaceholder = {
    official: t("providerForm.officialNoApiKey", {
      defaultValue: "官方供应商无需 API Key",
    }),
    thirdParty: t("providerForm.apiKeyAutoFill", {
      defaultValue: "输入 API Key，将自动填充到配置",
    }),
  };

  const finalPlaceholder = placeholder || defaultPlaceholder;

  return (
    <div className="space-y-1">
      <ApiKeyInput
        id={id}
        label={label}
        value={value}
        onChange={onChange}
        placeholder={
          category === "official"
            ? finalPlaceholder.official
            : finalPlaceholder.thirdParty
        }
        disabled={disabled ?? category === "official"}
      />
      {/* API Key 获取链接 */}
      {shouldShowLink && websiteUrl && (
        <div className="space-y-2 -mt-1 pl-1">
          <a
            href={websiteUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="text-xs text-green-400 dark:text-green-500 hover:text-green-500 dark:hover:text-green-400 transition-colors"
          >
            {t("providerForm.getApiKey", {
              defaultValue: "获取 API Key",
            })}
          </a>

          {/* 合作伙伴促销信息 - 已隐藏 */}
          {/* {isPartner && partnerPromotionKey && (
            <div className="rounded-md bg-green-50 dark:bg-green-950/30 p-2.5 border border-green-200 dark:border-green-800">
              <p className="text-xs leading-relaxed text-green-700 dark:text-green-300">
                💡{" "}
                {t(`providerForm.partnerPromotion.${partnerPromotionKey}`, {
                  defaultValue: "",
                })}
              </p>
            </div>
          )} */}
        </div>
      )}
    </div>
  );
}
