# priv/repo/seeds/geography_seed.exs
# Run with: mix run priv/repo/seeds/geography_seed.exs
#
# Seeds all 7 provinces, all 77 districts, and key local bodies.
# is_service_available: true for Kathmandu Valley municipalities where
# 10-min delivery is realistic; expand as you grow.

alias Qcommerce.Repo
alias Qcommerce.Geography.{Province, District, LocalBody}

import Ecto.Query

defmodule GeographySeed do
  def upsert_province!(attrs) do
    case Repo.get_by(Province, code: attrs.code) do
      nil -> Repo.insert!(%Province{} |> Province.changeset(attrs))
      existing -> existing
    end
  end

  def upsert_district!(attrs, province_id) do
    case Repo.get_by(District, name: attrs.name) do
      nil ->
        Repo.insert!(%District{} |> District.changeset(Map.put(attrs, :province_id, province_id)))

      existing ->
        existing
    end
  end

  def upsert_local_body!(attrs, district_id) do
    case Repo.one(
           from lb in LocalBody,
             where:
               lb.district_id == ^district_id and lb.name == ^attrs.name and
                 lb.type == ^to_string(attrs.type)
         ) do
      nil ->
        Repo.insert!(
          %LocalBody{}
          |> LocalBody.changeset(Map.put(attrs, :district_id, district_id))
        )

      existing ->
        existing
    end
  end
end

# ---------------------------------------------------------------------------
# 7 Provinces
# ---------------------------------------------------------------------------
provinces_data = [
  %{code: "1", name: "Koshi Province", name_nepali: "कोशी प्रदेश"},
  %{code: "2", name: "Madhesh Province", name_nepali: "मधेश प्रदेश"},
  %{code: "3", name: "Bagmati Province", name_nepali: "बागमती प्रदेश"},
  %{code: "4", name: "Gandaki Province", name_nepali: "गण्डकी प्रदेश"},
  %{code: "5", name: "Lumbini Province", name_nepali: "लुम्बिनी प्रदेश"},
  %{code: "6", name: "Karnali Province", name_nepali: "कर्णाली प्रदेश"},
  %{code: "7", name: "Sudurpashchim Province", name_nepali: "सुदूरपश्चिम प्रदेश"}
]

provinces =
  Map.new(provinces_data, fn p ->
    record = GeographySeed.upsert_province!(p)
    {p.code, record.id}
  end)

IO.puts("✅ Provinces seeded")

# ---------------------------------------------------------------------------
# Districts by province (all 77)
# ---------------------------------------------------------------------------
districts_by_province = %{
  "1" => [
    %{name: "Bhojpur", name_nepali: "भोजपुर"},
    %{name: "Dhankuta", name_nepali: "धनकुटा"},
    %{name: "Ilam", name_nepali: "इलाम"},
    %{name: "Jhapa", name_nepali: "झापा"},
    %{name: "Khotang", name_nepali: "खोटाङ"},
    %{name: "Morang", name_nepali: "मोरङ"},
    %{name: "Okhaldhunga", name_nepali: "ओखलढुङ्गा"},
    %{name: "Panchthar", name_nepali: "पाँचथर"},
    %{name: "Sankhuwasabha", name_nepali: "सङ्खुवासभा"},
    %{name: "Solukhumbu", name_nepali: "सोलुखुम्बु"},
    %{name: "Sunsari", name_nepali: "सुनसरी"},
    %{name: "Taplejung", name_nepali: "ताप्लेजुङ"},
    %{name: "Terhathum", name_nepali: "तेह्रथुम"},
    %{name: "Udayapur", name_nepali: "उदयपुर"}
  ],
  "2" => [
    %{name: "Bara", name_nepali: "बारा"},
    %{name: "Dhanusha", name_nepali: "धनुषा"},
    %{name: "Mahottari", name_nepali: "महोत्तरी"},
    %{name: "Parsa", name_nepali: "पर्सा"},
    %{name: "Rautahat", name_nepali: "रौतहट"},
    %{name: "Saptari", name_nepali: "सप्तरी"},
    %{name: "Sarlahi", name_nepali: "सर्लाही"},
    %{name: "Siraha", name_nepali: "सिरहा"}
  ],
  "3" => [
    %{name: "Bhaktapur", name_nepali: "भक्तपुर"},
    %{name: "Chitwan", name_nepali: "चितवन"},
    %{name: "Dhading", name_nepali: "धादिङ"},
    %{name: "Dolakha", name_nepali: "दोलखा"},
    %{name: "Kavrepalanchok", name_nepali: "काभ्रेपलाञ्चोक"},
    %{name: "Kathmandu", name_nepali: "काठमाडौँ"},
    %{name: "Lalitpur", name_nepali: "ललितपुर"},
    %{name: "Makwanpur", name_nepali: "मकवानपुर"},
    %{name: "Nuwakot", name_nepali: "नुवाकोट"},
    %{name: "Ramechhap", name_nepali: "रामेछाप"},
    %{name: "Rasuwa", name_nepali: "रसुवा"},
    %{name: "Sindhuli", name_nepali: "सिन्धुली"},
    %{name: "Sindhupalchok", name_nepali: "सिन्धुपाल्चोक"}
  ],
  "4" => [
    %{name: "Baglung", name_nepali: "बागलुङ"},
    %{name: "Gorkha", name_nepali: "गोरखा"},
    %{name: "Kaski", name_nepali: "कास्की"},
    %{name: "Lamjung", name_nepali: "लमजुङ"},
    %{name: "Manang", name_nepali: "मनाङ"},
    %{name: "Mustang", name_nepali: "मुस्ताङ"},
    %{name: "Myagdi", name_nepali: "म्याग्दी"},
    %{name: "Nawalpur", name_nepali: "नवलपुर"},
    %{name: "Parbat", name_nepali: "पर्वत"},
    %{name: "Syangja", name_nepali: "स्याङ्जा"},
    %{name: "Tanahun", name_nepali: "तनहुँ"}
  ],
  "5" => [
    %{name: "Arghakhanchi", name_nepali: "अर्घाखाँची"},
    %{name: "Banke", name_nepali: "बाँके"},
    %{name: "Bardiya", name_nepali: "बर्दिया"},
    %{name: "Dang", name_nepali: "दाङ"},
    %{name: "Eastern Rukum", name_nepali: "रुकुम पूर्व"},
    %{name: "Gulmi", name_nepali: "गुल्मी"},
    %{name: "Kapilvastu", name_nepali: "कपिलवस्तु"},
    %{name: "Nawalparasi East", name_nepali: "नवलपरासी पूर्व"},
    %{name: "Palpa", name_nepali: "पाल्पा"},
    %{name: "Pyuthan", name_nepali: "प्युठान"},
    %{name: "Rolpa", name_nepali: "रोल्पा"},
    %{name: "Rupandehi", name_nepali: "रुपन्देही"}
  ],
  "6" => [
    %{name: "Dailekh", name_nepali: "दैलेख"},
    %{name: "Dolpa", name_nepali: "डोल्पा"},
    %{name: "Humla", name_nepali: "हुम्ला"},
    %{name: "Jajarkot", name_nepali: "जाजरकोट"},
    %{name: "Jumla", name_nepali: "जुम्ला"},
    %{name: "Kalikot", name_nepali: "कालिकोट"},
    %{name: "Mugu", name_nepali: "मुगु"},
    %{name: "Rukum West", name_nepali: "रुकुम पश्चिम"},
    %{name: "Salyan", name_nepali: "सल्यान"},
    %{name: "Surkhet", name_nepali: "सुर्खेत"}
  ],
  "7" => [
    %{name: "Achham", name_nepali: "अछाम"},
    %{name: "Baitadi", name_nepali: "बैतडी"},
    %{name: "Bajhang", name_nepali: "बझाङ"},
    %{name: "Bajura", name_nepali: "बाजुरा"},
    %{name: "Dadeldhura", name_nepali: "डडेलधुरा"},
    %{name: "Darchula", name_nepali: "दार्चुला"},
    %{name: "Doti", name_nepali: "डोटी"},
    %{name: "Kailali", name_nepali: "कैलाली"},
    %{name: "Kanchanpur", name_nepali: "कञ्चनपुर"}
  ]
}

district_ids =
  Map.new(districts_by_province, fn {pcode, districts} ->
    province_id = provinces[pcode]

    ids =
      Map.new(districts, fn d ->
        record = GeographySeed.upsert_district!(d, province_id)
        {d.name, record.id}
      end)

    {pcode, ids}
  end)

IO.puts("✅ Districts seeded")

# ---------------------------------------------------------------------------
# Key local bodies — Kathmandu Valley (service_available: true)
# Expand as needed for your delivery zones.
# ---------------------------------------------------------------------------
kathmandu_id = district_ids["3"]["Kathmandu"]
lalitpur_id = district_ids["3"]["Lalitpur"]
bhaktapur_id = district_ids["3"]["Bhaktapur"]
chitwan_id = district_ids["3"]["Chitwan"]
kaski_id = district_ids["4"]["Kaski"]
sunsari_id = district_ids["1"]["Sunsari"]

local_bodies = [
  # Kathmandu District
  %{
    name: "Kathmandu",
    name_nepali: "काठमाडौँ",
    type: :metropolitan,
    number_of_wards: 32,
    is_service_available: true,
    district_id: kathmandu_id
  },
  %{
    name: "Kirtipur",
    name_nepali: "किर्तिपुर",
    type: :municipality,
    number_of_wards: 10,
    is_service_available: true,
    district_id: kathmandu_id
  },
  %{
    name: "Nagarjun",
    name_nepali: "नागार्जुन",
    type: :municipality,
    number_of_wards: 10,
    is_service_available: false,
    district_id: kathmandu_id
  },
  %{
    name: "Kageshwori Manohara",
    name_nepali: "काकेश्वरी",
    type: :municipality,
    number_of_wards: 9,
    is_service_available: false,
    district_id: kathmandu_id
  },
  %{
    name: "Gokarneshwor",
    name_nepali: "गोकर्णेश्वर",
    type: :municipality,
    number_of_wards: 9,
    is_service_available: false,
    district_id: kathmandu_id
  },
  %{
    name: "Shankharapur",
    name_nepali: "शङ्खरापुर",
    type: :municipality,
    number_of_wards: 9,
    is_service_available: false,
    district_id: kathmandu_id
  },
  %{
    name: "Tarakeshwor",
    name_nepali: "तारकेश्वर",
    type: :municipality,
    number_of_wards: 11,
    is_service_available: false,
    district_id: kathmandu_id
  },
  %{
    name: "Tokha",
    name_nepali: "टोखा",
    type: :municipality,
    number_of_wards: 11,
    is_service_available: true,
    district_id: kathmandu_id
  },
  %{
    name: "Budhanilkantha",
    name_nepali: "बुद्धनीलकण्ठ",
    type: :municipality,
    number_of_wards: 13,
    is_service_available: true,
    district_id: kathmandu_id
  },
  %{
    name: "Chandragiri",
    name_nepali: "चन्द्रागिरि",
    type: :municipality,
    number_of_wards: 15,
    is_service_available: true,
    district_id: kathmandu_id
  },
  %{
    name: "Dakshinkali",
    name_nepali: "दक्षिणकाली",
    type: :municipality,
    number_of_wards: 9,
    is_service_available: false,
    district_id: kathmandu_id
  },
  # Lalitpur District
  %{
    name: "Lalitpur",
    name_nepali: "ललितपुर",
    type: :metropolitan,
    number_of_wards: 29,
    is_service_available: true,
    district_id: lalitpur_id
  },
  %{
    name: "Godawari",
    name_nepali: "गोदावरी",
    type: :municipality,
    number_of_wards: 14,
    is_service_available: true,
    district_id: lalitpur_id
  },
  %{
    name: "Mahalaxmi",
    name_nepali: "महालक्ष्मी",
    type: :municipality,
    number_of_wards: 11,
    is_service_available: true,
    district_id: lalitpur_id
  },
  %{
    name: "Konjyosom",
    name_nepali: "कोञ्जोसोम",
    type: :rural_municipality,
    number_of_wards: 6,
    is_service_available: false,
    district_id: lalitpur_id
  },
  %{
    name: "Bagmati",
    name_nepali: "बागमती",
    type: :rural_municipality,
    number_of_wards: 7,
    is_service_available: false,
    district_id: lalitpur_id
  },
  # Bhaktapur District
  %{
    name: "Bhaktapur",
    name_nepali: "भक्तपुर",
    type: :municipality,
    number_of_wards: 10,
    is_service_available: true,
    district_id: bhaktapur_id
  },
  %{
    name: "Madhyapur Thimi",
    name_nepali: "मध्यपुर थिमि",
    type: :municipality,
    number_of_wards: 9,
    is_service_available: true,
    district_id: bhaktapur_id
  },
  %{
    name: "Changunarayan",
    name_nepali: "चाँगुनारायण",
    type: :municipality,
    number_of_wards: 9,
    is_service_available: false,
    district_id: bhaktapur_id
  },
  %{
    name: "Suryabinayak",
    name_nepali: "सूर्यबिनायक",
    type: :municipality,
    number_of_wards: 9,
    is_service_available: true,
    district_id: bhaktapur_id
  },
  # Chitwan
  %{
    name: "Bharatpur",
    name_nepali: "भरतपुर",
    type: :metropolitan,
    number_of_wards: 29,
    is_service_available: true,
    district_id: chitwan_id
  },
  %{
    name: "Ratnanagar",
    name_nepali: "रत्ननगर",
    type: :municipality,
    number_of_wards: 9,
    is_service_available: false,
    district_id: chitwan_id
  },
  # Kaski (Pokhara)
  %{
    name: "Pokhara",
    name_nepali: "पोखरा",
    type: :metropolitan,
    number_of_wards: 33,
    is_service_available: true,
    district_id: kaski_id
  },
  # Sunsari (Itahari)
  %{
    name: "Itahari",
    name_nepali: "इटहरी",
    type: :sub_metropolitan,
    number_of_wards: 11,
    is_service_available: true,
    district_id: sunsari_id
  },
  %{
    name: "Dharan",
    name_nepali: "धरान",
    type: :sub_metropolitan,
    number_of_wards: 19,
    is_service_available: true,
    district_id: sunsari_id
  }
]

Enum.each(local_bodies, fn lb ->
  district_id = lb.district_id
  attrs = Map.drop(lb, [:district_id])
  GeographySeed.upsert_local_body!(attrs, district_id)
end)

IO.puts("✅ Local bodies seeded (#{length(local_bodies)} records)")
IO.puts("🎉 Geography seed complete!")
