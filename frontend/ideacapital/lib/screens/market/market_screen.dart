import 'package:flutter/material.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IP Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MarketStatRow(),
          const SizedBox(height: 24),
          const Text(
            'Active Listings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _ListingCard(
            token: 'GreenTech-101',
            amount: 500,
            price: 250,
            seller: '0x71...2266',
          ),
          _ListingCard(
            token: 'BioMed-A4',
            amount: 1000,
            price: 900,
            seller: '0xAB...CDEF',
          ),
          // Placeholder for empty state logic later
        ],
      ),
    );
  }
}

class _MarketStatRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem('24h Volume', '\$12.5k'),
        _StatItem('Active Listings', '42'),
        _StatItem('Floor Price', '\$0.45'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}

class _ListingCard extends StatelessWidget {
  final String token;
  final int amount;
  final int price;
  final String seller;

  const _ListingCard({
    required this.token,
    required this.amount,
    required this.price,
    required this.seller,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Text(token[0])),
        title: Text('$amount $token'),
        subtitle: Text('Seller: $seller'),
        trailing: FilledButton(
          onPressed: () {
            // TODO: Wire up buyListing(id)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Buying coming in v0.6.1')),
            );
          },
          child: Text('Buy \$${price}'),
        ),
      ),
    );
  }
}
